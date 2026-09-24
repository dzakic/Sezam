#nullable enable
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace Sezam
{
    public enum ProxyProtocolMode
    {
        /// <summary>
        /// Automatically detect if the incoming stream begins with a PROXY protocol header.
        /// If present, parse and extract client IP; if not present, proceed as a normal direct connection.
        /// </summary>
        Auto,

        /// <summary>
        /// A PROXY protocol header is strictly required. Non-proxy or malformed connections will be rejected.
        /// </summary>
        Required,

        /// <summary>
        /// PROXY protocol detection is disabled. All connections are treated as direct connections.
        /// </summary>
        Disabled
    }

    public enum ProxyProtocolVersion
    {
        None,
        V1,
        V2
    }

    public class ProxyProtocolResult
    {
        public bool IsProxied { get; set; }
        public ProxyProtocolVersion Version { get; set; } = ProxyProtocolVersion.None;
        public IPEndPoint? RemoteEndPoint { get; set; }
        public IPAddress? RemoteIPAddress => RemoteEndPoint?.Address;
        public int RemotePort => RemoteEndPoint?.Port ?? 0;
        public IPEndPoint? DestinationEndPoint { get; set; }
        public byte[]? LeftoverBytes { get; set; } = Array.Empty<byte>();

        public static ProxyProtocolResult Direct(byte[]? leftoverBytes = null) =>
            new() { IsProxied = false, LeftoverBytes = leftoverBytes ?? Array.Empty<byte>() };
    }

    public class ProxyProtocolException : Exception
    {
        public ProxyProtocolException(string message) : base(message) { }
        public ProxyProtocolException(string message, Exception innerException) : base(message, innerException) { }
    }

    /// <summary>
    /// Implements HAProxy PROXY Protocol v1 (text) and v2 (binary) interception.
    /// Used by NGINX stream proxy with 'proxy_protocol on;' to identify the real remote IP of clients.
    /// </summary>
    public static class ProxyProtocolParser
    {
        // PROXY v1 magic: "PROXY "
        private static readonly byte[] V1Signature = "PROXY "u8.ToArray();

        // PROXY v2 magic: 12-byte fixed sequence \x0D\x0A\x0D\x0A\x00\x0D\x0A\x51\x55\x49\x54\x0A
        private static readonly byte[] V2Signature = new byte[]
        {
            0x0D, 0x0A, 0x0D, 0x0A, 0x00, 0x0D, 0x0A, 0x51, 0x55, 0x49, 0x54, 0x0A
        };

        private const int MaxV1HeaderLength = 108; // 107 max line length + \n
        private const int V2FixedHeaderLength = 16; // 12 signature + 1 ver/cmd + 1 fam/proto + 2 len

        /// <summary>
        /// Parse proxy protocol mode from a string configuration value.
        /// </summary>
        public static ProxyProtocolMode ParseMode(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return ProxyProtocolMode.Auto;

            var trimmed = value.Trim();
            if (trimmed.Equals("Required", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Equals("true", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Equals("1", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Equals("on", StringComparison.OrdinalIgnoreCase))
            {
                return ProxyProtocolMode.Required;
            }

            if (trimmed.Equals("Disabled", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Equals("false", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Equals("0", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Equals("off", StringComparison.OrdinalIgnoreCase))
            {
                return ProxyProtocolMode.Disabled;
            }

            return ProxyProtocolMode.Auto;
        }

        /// <summary>
        /// Detects and parses the PROXY protocol header from the network stream according to the specified mode.
        /// Any excess bytes read past the header are preserved in ProxyProtocolResult.LeftoverBytes.
        /// </summary>
        public static async Task<ProxyProtocolResult> DetectAndParseAsync(
            Stream stream,
            ProxyProtocolMode mode,
            ILogger? logger = null,
            int autoTimeoutMs = 250,
            int requiredTimeoutMs = 5000,
            CancellationToken cancellationToken = default)
        {
            if (mode == ProxyProtocolMode.Disabled)
                return ProxyProtocolResult.Direct();

            var timeoutMs = mode == ProxyProtocolMode.Required ? requiredTimeoutMs : autoTimeoutMs;
            using var timeoutCts = new CancellationTokenSource(timeoutMs);
            using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeoutCts.Token);

            byte[] buffer = new byte[512];
            int bytesRead = 0;

            try
            {
                // Read initial chunk to inspect header
                bytesRead = await stream.ReadAsync(buffer, 0, buffer.Length, linkedCts.Token).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested && !cancellationToken.IsCancellationRequested)
            {
                // Timeout elapsed waiting for initial bytes
                if (mode == ProxyProtocolMode.Required)
                {
                    throw new ProxyProtocolException($"Timeout ({timeoutMs}ms) waiting for required PROXY protocol header.");
                }

                // In Auto mode, timeout means this is a direct connection where the client is waiting for server greeting
                logger?.LogDebug("Auto-detection timed out after {TimeoutMs}ms; proceeding as direct connection.", timeoutMs);
                return ProxyProtocolResult.Direct();
            }

            if (bytesRead == 0)
            {
                // Connection closed by client
                if (mode == ProxyProtocolMode.Required)
                    throw new ProxyProtocolException("Connection closed by peer before PROXY protocol header was received.");
                return ProxyProtocolResult.Direct();
            }

            var initialSpan = buffer.AsSpan(0, bytesRead);

            // Check for PROXY v1: starts with "PROXY "
            if (StartsWith(initialSpan, V1Signature))
            {
                return await ParseV1Async(stream, buffer, bytesRead, linkedCts.Token).ConfigureAwait(false);
            }

            // Check for PROXY v2: starts with 12-byte binary signature
            if (StartsWith(initialSpan, V2Signature))
            {
                return await ParseV2Async(stream, buffer, bytesRead, linkedCts.Token).ConfigureAwait(false);
            }

            // Neither signature matched
            if (mode == ProxyProtocolMode.Required)
            {
                throw new ProxyProtocolException("Invalid connection: PROXY protocol header is required, but header signature was not found.");
            }

            // In Auto mode, data arrived that is not PROXY protocol; preserve all bytes read for the client session
            byte[] directLeftover = new byte[bytesRead];
            Array.Copy(buffer, 0, directLeftover, 0, bytesRead);
            return ProxyProtocolResult.Direct(directLeftover);
        }

        private static bool StartsWith(ReadOnlySpan<byte> data, byte[] prefix)
        {
            if (data.Length < prefix.Length)
            {
                // If data has fewer bytes than prefix, check if all available bytes match prefix
                return data.SequenceEqual(prefix.AsSpan(0, data.Length));
            }
            return data.Slice(0, prefix.Length).SequenceEqual(prefix);
        }

        /// <summary>
        /// Reads until CRLF is found, up to MaxV1HeaderLength (108 bytes).
        /// Format: PROXY <INET_PROTOCOL> <SRC_IP> <DST_IP> <SRC_PORT> <DST_PORT>\r\n
        /// or: PROXY UNKNOWN ...\r\n
        /// </summary>
        private static async Task<ProxyProtocolResult> ParseV1Async(
            Stream stream,
            byte[] buffer,
            int bytesRead,
            CancellationToken cancellationToken)
        {
            int crlfIndex = FindCrlf(buffer, 0, bytesRead);

            while (crlfIndex == -1)
            {
                if (bytesRead >= MaxV1HeaderLength)
                {
                    throw new ProxyProtocolException($"PROXY v1 header exceeded maximum length of {MaxV1HeaderLength} bytes without CRLF.");
                }

                int needed = Math.Min(buffer.Length - bytesRead, MaxV1HeaderLength - bytesRead);
                int additional = await stream.ReadAsync(buffer, bytesRead, needed, cancellationToken).ConfigureAwait(false);
                if (additional == 0)
                {
                    throw new ProxyProtocolException("Connection closed while reading PROXY v1 header.");
                }

                bytesRead += additional;
                crlfIndex = FindCrlf(buffer, 0, bytesRead);
            }

            // Header line up to CRLF (excluding \r\n)
            var headerLine = Encoding.ASCII.GetString(buffer, 0, crlfIndex);

            // Compute leftover bytes after \r\n
            int headerTotalLength = crlfIndex + 2;
            int leftoverLength = bytesRead - headerTotalLength;
            byte[] leftover = Array.Empty<byte>();
            if (leftoverLength > 0)
            {
                leftover = new byte[leftoverLength];
                Array.Copy(buffer, headerTotalLength, leftover, 0, leftoverLength);
            }

            // Parse tokens: "PROXY", INET_PROTOCOL, SRC_IP, DST_IP, SRC_PORT, DST_PORT
            var parts = headerLine.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 2 || parts[0] != "PROXY")
            {
                throw new ProxyProtocolException($"Malformed PROXY v1 header: '{headerLine}'");
            }

            var inetProtocol = parts[1].ToUpperInvariant();
            if (inetProtocol == "UNKNOWN")
            {
                // Spec: UNKNOWN may be sent for health checks or non-TCP traffic. Real socket IP should be preserved.
                return new ProxyProtocolResult
                {
                    IsProxied = true,
                    Version = ProxyProtocolVersion.V1,
                    RemoteEndPoint = null,
                    LeftoverBytes = leftover
                };
            }

            if (parts.Length < 6)
            {
                throw new ProxyProtocolException($"Malformed PROXY v1 header line: expected 6 fields, got {parts.Length}.");
            }

            if (inetProtocol != "TCP4" && inetProtocol != "TCP6")
            {
                throw new ProxyProtocolException($"Unsupported PROXY v1 protocol: '{inetProtocol}'. Expected TCP4, TCP6, or UNKNOWN.");
            }

            if (!IPAddress.TryParse(parts[2], out var srcIp))
            {
                throw new ProxyProtocolException($"Invalid source IP address in PROXY v1 header: '{parts[2]}'");
            }

            if (!IPAddress.TryParse(parts[3], out var dstIp))
            {
                throw new ProxyProtocolException($"Invalid destination IP address in PROXY v1 header: '{parts[3]}'");
            }

            if (!ushort.TryParse(parts[4], out var srcPort))
            {
                throw new ProxyProtocolException($"Invalid source port in PROXY v1 header: '{parts[4]}'");
            }

            if (!ushort.TryParse(parts[5], out var dstPort))
            {
                throw new ProxyProtocolException($"Invalid destination port in PROXY v1 header: '{parts[5]}'");
            }

            return new ProxyProtocolResult
            {
                IsProxied = true,
                Version = ProxyProtocolVersion.V1,
                RemoteEndPoint = new IPEndPoint(srcIp, srcPort),
                DestinationEndPoint = new IPEndPoint(dstIp, dstPort),
                LeftoverBytes = leftover
            };
        }

        private static int FindCrlf(byte[] buffer, int offset, int count)
        {
            for (int i = offset; i < offset + count - 1; i++)
            {
                if (buffer[i] == 0x0D && buffer[i + 1] == 0x0A)
                    return i;
            }
            return -1;
        }

        /// <summary>
        /// Parses binary PROXY Protocol v2.
        /// Fixed 16-byte header:
        /// 12 bytes signature + 1 byte ver/cmd + 1 byte fam/proto + 2 bytes big-endian length.
        /// Followed by address structure and optional TLVs.
        /// </summary>
        private static async Task<ProxyProtocolResult> ParseV2Async(
            Stream stream,
            byte[] buffer,
            int bytesRead,
            CancellationToken cancellationToken)
        {
            // Ensure we have at least the 16-byte fixed header
            while (bytesRead < V2FixedHeaderLength)
            {
                int needed = V2FixedHeaderLength - bytesRead;
                int additional = await stream.ReadAsync(buffer, bytesRead, needed, cancellationToken).ConfigureAwait(false);
                if (additional == 0)
                    throw new ProxyProtocolException("Connection closed while reading PROXY v2 fixed header.");
                bytesRead += additional;
            }

            byte verCmd = buffer[12];
            int version = (verCmd >> 4) & 0x0F;
            int command = verCmd & 0x0F;

            if (version != 2)
            {
                throw new ProxyProtocolException($"Unsupported PROXY protocol version: {version}. Expected version 2.");
            }

            byte famProto = buffer[13];
            int family = (famProto >> 4) & 0x0F;
            int protocol = famProto & 0x0F;

            // 2-byte big-endian payload length (address struct + TLVs)
            ushort payloadLength = (ushort)((buffer[14] << 8) | buffer[15]);
            int totalHeaderSize = V2FixedHeaderLength + payloadLength;

            // If buffer is too small for payload, expand it
            if (buffer.Length < totalHeaderSize)
            {
                var newBuffer = new byte[totalHeaderSize + 256];
                Array.Copy(buffer, 0, newBuffer, 0, bytesRead);
                buffer = newBuffer;
            }

            // Read the full payload (addresses + TLVs)
            while (bytesRead < totalHeaderSize)
            {
                int needed = totalHeaderSize - bytesRead;
                int additional = await stream.ReadAsync(buffer, bytesRead, needed, cancellationToken).ConfigureAwait(false);
                if (additional == 0)
                    throw new ProxyProtocolException("Connection closed while reading PROXY v2 payload.");
                bytesRead += additional;
            }

            int leftoverLength = bytesRead - totalHeaderSize;
            byte[] leftover = Array.Empty<byte>();
            if (leftoverLength > 0)
            {
                leftover = new byte[leftoverLength];
                Array.Copy(buffer, totalHeaderSize, leftover, 0, leftoverLength);
            }

            // Command 0x00 = LOCAL (e.g. proxy health-check). Skip address parsing and use socket endpoint.
            if (command == 0x00)
            {
                return new ProxyProtocolResult
                {
                    IsProxied = true,
                    Version = ProxyProtocolVersion.V2,
                    RemoteEndPoint = null,
                    LeftoverBytes = leftover
                };
            }

            if (command != 0x01) // 0x01 = PROXY
            {
                throw new ProxyProtocolException($"Unsupported PROXY v2 command: 0x{command:X2}");
            }

            IPEndPoint? remoteEp = null;
            IPEndPoint? dstEp = null;

            // Address family: 1 = AF_INET (IPv4), 2 = AF_INET6 (IPv6)
            // Protocol: 1 = STREAM (TCP)
            if (family == 0x01 && protocol == 0x01) // IPv4 TCP
            {
                if (payloadLength < 12)
                    throw new ProxyProtocolException($"PROXY v2 IPv4 payload too short: {payloadLength} bytes, expected >= 12.");

                byte[] srcIpBytes = new byte[4];
                byte[] dstIpBytes = new byte[4];
                Array.Copy(buffer, 16, srcIpBytes, 0, 4);
                Array.Copy(buffer, 20, dstIpBytes, 0, 4);

                ushort srcPort = (ushort)((buffer[24] << 8) | buffer[25]);
                ushort dstPort = (ushort)((buffer[26] << 8) | buffer[27]);

                remoteEp = new IPEndPoint(new IPAddress(srcIpBytes), srcPort);
                dstEp = new IPEndPoint(new IPAddress(dstIpBytes), dstPort);
            }
            else if (family == 0x02 && protocol == 0x01) // IPv6 TCP
            {
                if (payloadLength < 36)
                    throw new ProxyProtocolException($"PROXY v2 IPv6 payload too short: {payloadLength} bytes, expected >= 36.");

                byte[] srcIpBytes = new byte[16];
                byte[] dstIpBytes = new byte[16];
                Array.Copy(buffer, 16, srcIpBytes, 0, 16);
                Array.Copy(buffer, 32, dstIpBytes, 0, 16);

                ushort srcPort = (ushort)((buffer[48] << 8) | buffer[49]);
                ushort dstPort = (ushort)((buffer[50] << 8) | buffer[51]);

                remoteEp = new IPEndPoint(new IPAddress(srcIpBytes), srcPort);
                dstEp = new IPEndPoint(new IPAddress(dstIpBytes), dstPort);
            }
            else
            {
                // Other families (UNIX domain socket or UNSPEC)
                // Use socket address as fallback
            }

            return new ProxyProtocolResult
            {
                IsProxied = true,
                Version = ProxyProtocolVersion.V2,
                RemoteEndPoint = remoteEp,
                DestinationEndPoint = dstEp,
                LeftoverBytes = leftover
            };
        }
    }
}
