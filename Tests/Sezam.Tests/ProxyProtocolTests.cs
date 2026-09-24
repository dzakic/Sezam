using System;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Sezam.Tests
{
    [TestFixture]
    public class ProxyProtocolTests
    {
        [Test]
        public async Task DetectAndParseAsync_V1_Ipv4_ParsesCorrectly()
        {
            var header = "PROXY TCP4 203.0.113.195 198.51.100.1 56324 2023\r\n";
            using var stream = new MemoryStream(Encoding.ASCII.GetBytes(header));

            var result = await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Auto);

            Assert.That(result.IsProxied, Is.True);
            Assert.That(result.Version, Is.EqualTo(ProxyProtocolVersion.V1));
            Assert.That(result.RemoteEndPoint, Is.Not.Null);
            Assert.That(result.RemoteEndPoint?.Address, Is.EqualTo(IPAddress.Parse("203.0.113.195")));
            Assert.That(result.RemoteEndPoint?.Port, Is.EqualTo(56324));
            Assert.That(result.DestinationEndPoint, Is.Not.Null);
            Assert.That(result.DestinationEndPoint?.Address, Is.EqualTo(IPAddress.Parse("198.51.100.1")));
            Assert.That(result.DestinationEndPoint?.Port, Is.EqualTo(2023));
            Assert.That(result.LeftoverBytes, Is.Empty);
        }

        [Test]
        public async Task DetectAndParseAsync_V1_Ipv6_ParsesCorrectly()
        {
            var header = "PROXY TCP6 2001:db8::1 2001:db8::2 56324 2023\r\n";
            using var stream = new MemoryStream(Encoding.ASCII.GetBytes(header));

            var result = await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Auto);

            Assert.That(result.IsProxied, Is.True);
            Assert.That(result.Version, Is.EqualTo(ProxyProtocolVersion.V1));
            Assert.That(result.RemoteEndPoint, Is.Not.Null);
            Assert.That(result.RemoteEndPoint?.Address, Is.EqualTo(IPAddress.Parse("2001:db8::1")));
            Assert.That(result.RemoteEndPoint?.Port, Is.EqualTo(56324));
            Assert.That(result.DestinationEndPoint, Is.Not.Null);
            Assert.That(result.DestinationEndPoint?.Address, Is.EqualTo(IPAddress.Parse("2001:db8::2")));
            Assert.That(result.DestinationEndPoint?.Port, Is.EqualTo(2023));
            Assert.That(result.LeftoverBytes, Is.Empty);
        }

        [Test]
        public async Task DetectAndParseAsync_V1_Unknown_ReturnsNullRemoteEndPoint()
        {
            var header = "PROXY UNKNOWN\r\n";
            using var stream = new MemoryStream(Encoding.ASCII.GetBytes(header));

            var result = await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Auto);

            Assert.That(result.IsProxied, Is.True);
            Assert.That(result.Version, Is.EqualTo(ProxyProtocolVersion.V1));
            Assert.That(result.RemoteEndPoint, Is.Null);
            Assert.That(result.LeftoverBytes, Is.Empty);
        }

        [Test]
        public async Task DetectAndParseAsync_V1_WithLeftoverBytes_PreservesLeftover()
        {
            var header = "PROXY TCP4 1.2.3.4 5.6.7.8 1234 2023\r\nTelnetInputData";
            using var stream = new MemoryStream(Encoding.ASCII.GetBytes(header));

            var result = await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Auto);

            Assert.That(result.IsProxied, Is.True);
            Assert.That(result.RemoteEndPoint?.Address, Is.EqualTo(IPAddress.Parse("1.2.3.4")));
            Assert.That(result.RemoteEndPoint?.Port, Is.EqualTo(1234));
            var leftover = result.LeftoverBytes ?? Array.Empty<byte>();
            Assert.That(Encoding.ASCII.GetString(leftover), Is.EqualTo("TelnetInputData"));
        }

        [Test]
        public async Task DetectAndParseAsync_V1_AcrossChunks_ReassemblesAndParses()
        {
            var header = "PROXY TCP4 192.168.10.20 10.0.0.1 40000 2023\r\nMoreData";
            using var stream = new ChunkedMemoryStream(Encoding.ASCII.GetBytes(header), chunkSize: 7);

            var result = await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Auto);

            Assert.That(result.IsProxied, Is.True);
            Assert.That(result.RemoteEndPoint?.Address, Is.EqualTo(IPAddress.Parse("192.168.10.20")));
            Assert.That(result.RemoteEndPoint?.Port, Is.EqualTo(40000));

            // Verify leftover bytes plus remaining stream bytes preserve all client payload data
            using var combined = new MemoryStream();
            combined.Write(result.LeftoverBytes);
            await stream.CopyToAsync(combined);
            Assert.That(Encoding.ASCII.GetString(combined.ToArray()), Is.EqualTo("MoreData"));
        }

        [Test]
        public async Task DetectAndParseAsync_V2_Ipv4_ParsesCorrectly()
        {
            var v2Data = CreateV2Header(
                command: 0x01, // PROXY
                family: 0x01,  // AF_INET
                protocol: 0x01, // STREAM
                srcIp: IPAddress.Parse("192.168.1.100"),
                dstIp: IPAddress.Parse("10.0.0.2"),
                srcPort: 54321,
                dstPort: 2023,
                extraPayload: Encoding.ASCII.GetBytes("AfterV2")
            );

            using var stream = new MemoryStream(v2Data);
            var result = await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Auto);

            Assert.That(result.IsProxied, Is.True);
            Assert.That(result.Version, Is.EqualTo(ProxyProtocolVersion.V2));
            Assert.That(result.RemoteEndPoint, Is.Not.Null);
            Assert.That(result.RemoteEndPoint?.Address, Is.EqualTo(IPAddress.Parse("192.168.1.100")));
            Assert.That(result.RemoteEndPoint?.Port, Is.EqualTo(54321));
            Assert.That(result.DestinationEndPoint, Is.Not.Null);
            Assert.That(result.DestinationEndPoint?.Address, Is.EqualTo(IPAddress.Parse("10.0.0.2")));
            Assert.That(result.DestinationEndPoint?.Port, Is.EqualTo(2023));
            Assert.That(Encoding.ASCII.GetString(result.LeftoverBytes ?? Array.Empty<byte>()), Is.EqualTo("AfterV2"));
        }

        [Test]
        public async Task DetectAndParseAsync_V2_Ipv6_ParsesCorrectly()
        {
            var v2Data = CreateV2Header(
                command: 0x01, // PROXY
                family: 0x02,  // AF_INET6
                protocol: 0x01, // STREAM
                srcIp: IPAddress.Parse("2001:db8::10"),
                dstIp: IPAddress.Parse("2001:db8::20"),
                srcPort: 45000,
                dstPort: 2023,
                extraPayload: Array.Empty<byte>()
            );

            using var stream = new MemoryStream(v2Data);
            var result = await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Auto);

            Assert.That(result.IsProxied, Is.True);
            Assert.That(result.Version, Is.EqualTo(ProxyProtocolVersion.V2));
            Assert.That(result.RemoteEndPoint?.Address, Is.EqualTo(IPAddress.Parse("2001:db8::10")));
            Assert.That(result.RemoteEndPoint?.Port, Is.EqualTo(45000));
            Assert.That(result.DestinationEndPoint?.Address, Is.EqualTo(IPAddress.Parse("2001:db8::20")));
            Assert.That(result.DestinationEndPoint?.Port, Is.EqualTo(2023));
        }

        [Test]
        public async Task DetectAndParseAsync_V2_Local_ReturnsNullRemoteEndPoint()
        {
            var v2Data = CreateV2Header(
                command: 0x00, // LOCAL
                family: 0x00,  // AF_UNSPEC
                protocol: 0x00,
                srcIp: IPAddress.Any,
                dstIp: IPAddress.Any,
                srcPort: 0,
                dstPort: 0,
                extraPayload: Encoding.ASCII.GetBytes("ProbeData")
            );

            using var stream = new MemoryStream(v2Data);
            var result = await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Auto);

            Assert.That(result.IsProxied, Is.True);
            Assert.That(result.Version, Is.EqualTo(ProxyProtocolVersion.V2));
            Assert.That(result.RemoteEndPoint, Is.Null);
            Assert.That(Encoding.ASCII.GetString(result.LeftoverBytes ?? Array.Empty<byte>()), Is.EqualTo("ProbeData"));
        }

        [Test]
        public async Task DetectAndParseAsync_AutoMode_DirectConnection_PreservesBytes()
        {
            // Direct client sending telnet negotiation immediately (e.g. IAC WILL ECHO)
            byte[] directData = new byte[] { 0xFF, 0xFB, 0x01 };
            using var stream = new MemoryStream(directData);

            var result = await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Auto);

            Assert.That(result.IsProxied, Is.False);
            Assert.That(result.Version, Is.EqualTo(ProxyProtocolVersion.None));
            Assert.That(result.RemoteEndPoint, Is.Null);
            Assert.That(result.LeftoverBytes, Is.EqualTo(directData));
        }

        [Test]
        public async Task DetectAndParseAsync_DisabledMode_ReturnsDirectImmediately()
        {
            var header = "PROXY TCP4 1.2.3.4 5.6.7.8 1234 2023\r\n";
            using var stream = new MemoryStream(Encoding.ASCII.GetBytes(header));

            var result = await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Disabled);

            Assert.That(result.IsProxied, Is.False);
            Assert.That(result.RemoteEndPoint, Is.Null);
        }

        [Test]
        public void DetectAndParseAsync_RequiredMode_NonProxyData_ThrowsException()
        {
            byte[] nonProxyData = Encoding.ASCII.GetBytes("GET / HTTP/1.1\r\n");
            using var stream = new MemoryStream(nonProxyData);

            Assert.ThrowsAsync<ProxyProtocolException>(async () =>
            {
                await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Required, requiredTimeoutMs: 1000);
            });
        }

        [Test]
        public void DetectAndParseAsync_V1_LineTooLong_ThrowsException()
        {
            // Create > 108 bytes without CRLF
            var longLine = "PROXY TCP4 " + new string('a', 120);
            using var stream = new MemoryStream(Encoding.ASCII.GetBytes(longLine));

            Assert.ThrowsAsync<ProxyProtocolException>(async () =>
            {
                await ProxyProtocolParser.DetectAndParseAsync(stream, ProxyProtocolMode.Auto);
            });
        }

        [TestCase("Required", ProxyProtocolMode.Required)]
        [TestCase("required", ProxyProtocolMode.Required)]
        [TestCase("true", ProxyProtocolMode.Required)]
        [TestCase("1", ProxyProtocolMode.Required)]
        [TestCase("on", ProxyProtocolMode.Required)]
        [TestCase("Disabled", ProxyProtocolMode.Disabled)]
        [TestCase("disabled", ProxyProtocolMode.Disabled)]
        [TestCase("false", ProxyProtocolMode.Disabled)]
        [TestCase("0", ProxyProtocolMode.Disabled)]
        [TestCase("off", ProxyProtocolMode.Disabled)]
        [TestCase("Auto", ProxyProtocolMode.Auto)]
        [TestCase("auto", ProxyProtocolMode.Auto)]
        [TestCase("", ProxyProtocolMode.Auto)]
        [TestCase(null, ProxyProtocolMode.Auto)]
        public void ParseMode_ConfigStrings_ReturnsExpectedEnum(string? input, ProxyProtocolMode expected)
        {
            Assert.That(ProxyProtocolParser.ParseMode(input), Is.EqualTo(expected));
        }

        [Test]
        public async Task TelnetTerminal_InitializesWithProxyProtocol_ExtractsRemoteIpAndPort()
        {
            var listener = new System.Net.Sockets.TcpListener(IPAddress.Loopback, 0);
            listener.Start();
            var port = ((IPEndPoint)listener.LocalEndpoint).Port;

            var clientTask = Task.Run(async () =>
            {
                var client = new System.Net.Sockets.TcpClient();
                await client.ConnectAsync(IPAddress.Loopback, port);
                var stream = client.GetStream();
                var proxyLine = Encoding.ASCII.GetBytes("PROXY TCP4 203.0.113.88 127.0.0.1 59999 2023\r\n");
                await stream.WriteAsync(proxyLine);
                await stream.FlushAsync();
                return client;
            });

            var serverClient = await listener.AcceptTcpClientAsync();
            var clientSide = await clientTask;

            try
            {
                var terminal = new TelnetTerminal(serverClient, ProxyProtocolMode.Auto);
                await terminal.InitializeAsync();

                Assert.That(terminal.IsProxied, Is.True);
                Assert.That(terminal.RemoteEndPoint, Is.Not.Null);
                Assert.That(terminal.RemoteEndPoint?.ToString(), Is.EqualTo("203.0.113.88:59999"));
                Assert.That(terminal.RemoteIPAddress, Is.EqualTo(IPAddress.Parse("203.0.113.88")));
                Assert.That(terminal.Id, Is.EqualTo("203.0.113.88:59999"));
            }
            finally
            {
                serverClient.Dispose();
                clientSide.Dispose();
                listener.Stop();
            }
        }

        [Test]
        public async Task TelnetTerminal_DirectConnection_DoesNotHangAndUsesSocketEndpoint()
        {
            var listener = new System.Net.Sockets.TcpListener(IPAddress.Loopback, 0);
            listener.Start();
            var port = ((IPEndPoint)listener.LocalEndpoint).Port;

            var clientTask = Task.Run(async () =>
            {
                var client = new System.Net.Sockets.TcpClient();
                await client.ConnectAsync(IPAddress.Loopback, port);
                return client;
            });

            var serverClient = await listener.AcceptTcpClientAsync();
            var clientSide = await clientTask;

            try
            {
                var terminal = new TelnetTerminal(serverClient, ProxyProtocolMode.Auto);
                await terminal.InitializeAsync();

                Assert.That(terminal.IsProxied, Is.False);
                Assert.That(terminal.RemoteEndPoint, Is.Not.Null);
                Assert.That(terminal.RemoteIPAddress, Is.EqualTo(IPAddress.Loopback));
                Assert.That(terminal.Id, Does.StartWith("127.0.0.1:"));
            }
            finally
            {
                serverClient.Dispose();
                clientSide.Dispose();
                listener.Stop();
            }
        }

        private static byte[] CreateV2Header(
            byte command,
            byte family,
            byte protocol,
            IPAddress srcIp,
            IPAddress dstIp,
            ushort srcPort,
            ushort dstPort,
            byte[] extraPayload)
        {
            byte[] sig = new byte[] { 0x0D, 0x0A, 0x0D, 0x0A, 0x00, 0x0D, 0x0A, 0x51, 0x55, 0x49, 0x54, 0x0A };
            byte verCmd = (byte)((2 << 4) | (command & 0x0F));
            byte famProto = (byte)(((family & 0x0F) << 4) | (protocol & 0x0F));

            byte[] addrBytes;
            if (family == 0x01) // IPv4
            {
                addrBytes = new byte[12];
                srcIp.GetAddressBytes().CopyTo(addrBytes, 0);
                dstIp.GetAddressBytes().CopyTo(addrBytes, 4);
                addrBytes[8] = (byte)(srcPort >> 8);
                addrBytes[9] = (byte)(srcPort & 0xFF);
                addrBytes[10] = (byte)(dstPort >> 8);
                addrBytes[11] = (byte)(dstPort & 0xFF);
            }
            else if (family == 0x02) // IPv6
            {
                addrBytes = new byte[36];
                srcIp.GetAddressBytes().CopyTo(addrBytes, 0);
                dstIp.GetAddressBytes().CopyTo(addrBytes, 16);
                addrBytes[32] = (byte)(srcPort >> 8);
                addrBytes[33] = (byte)(srcPort & 0xFF);
                addrBytes[34] = (byte)(dstPort >> 8);
                addrBytes[35] = (byte)(dstPort & 0xFF);
            }
            else
            {
                addrBytes = Array.Empty<byte>();
            }

            ushort payloadLength = (ushort)addrBytes.Length;
            byte lenHi = (byte)(payloadLength >> 8);
            byte lenLo = (byte)(payloadLength & 0xFF);

            using var ms = new MemoryStream();
            ms.Write(sig);
            ms.WriteByte(verCmd);
            ms.WriteByte(famProto);
            ms.WriteByte(lenHi);
            ms.WriteByte(lenLo);
            ms.Write(addrBytes);
            if (extraPayload.Length > 0)
                ms.Write(extraPayload);

            return ms.ToArray();
        }

        private class ChunkedMemoryStream : MemoryStream
        {
            private readonly int chunkSize;

            public ChunkedMemoryStream(byte[] buffer, int chunkSize) : base(buffer)
            {
                this.chunkSize = chunkSize;
            }

            public override int Read(byte[] buffer, int offset, int count)
            {
                return base.Read(buffer, offset, Math.Min(count, chunkSize));
            }

            public override Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken)
            {
                return base.ReadAsync(buffer, offset, Math.Min(count, chunkSize), cancellationToken);
            }

            public override ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default)
            {
                var slice = buffer.Length > chunkSize ? buffer.Slice(0, chunkSize) : buffer;
                return base.ReadAsync(slice, cancellationToken);
            }
        }
    }
}
