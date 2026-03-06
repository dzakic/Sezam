using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Sockets;
using System.Text;

namespace Sezam
{
    public class TelnetTerminal : Terminal, ITerminal
    {
        public override int LineWidth => lineWidth;

        // Telnet Protocol: http://support2.microsoft.com/kb/231866

        private enum Command
        {
            // interpret as command
            IAC = 255,

            DONT = 254,
            DO = 253,
            WONT = 252,
            WILL = 251,

            // subnegotiation begin
            SB = 250,

            // subnegotiation end
            SE = 240,

            NOP = 241,
            BRK = 243,

            // are you there
            AYT = 246,

            // erase line
            EL = 248,
        }

        private enum Option
        {
            NONE = -1,
            BinaryTransmission = 0,
            Echo = 1,
            Reconnection = 2,
            SuppressGoAhead = 3,
            Status = 5,
            ExtendedAscii = 17,
            TerminalType = 24,
            NegotiateAboutWindowSize = 31,
            TerminalSpeed = 32,
            LineMode = 34,
            NewEnvironment = 39
        }

        private class TelnetOption
        {
            private const int MAXRETRY = 2;

            internal TelnetOption(Option code, bool myDesired, bool? clientDesired = null)
            {
                opt = code;
                myDesiredState = myDesired;
                clientDesiredState = clientDesired;
            }
            
            public bool ClientCommandConflictsDesired(Command cmd)
            {
                if (clientDesiredState is null || clientRequestCount > MAXRETRY)
                    return false;
                
                bool conflict = (cmd == Command.WILL && clientDesiredState.Value == false) ||
                    (cmd == Command.WONT && clientDesiredState.Value == true);
                
                if (conflict)
                    clientRequestCount++;
                return conflict;
            }

            public bool MyCommandConflictsDesired(Command cmd)
            {
                if (myRequestCount > MAXRETRY)
                    return false;
                
                bool conflict = (cmd == Command.DO && myDesiredState == false) ||
                    (cmd == Command.DONT && myDesiredState == true);
                if (conflict)
                    myRequestCount++;
                return conflict;
            }

            public Option opt;
            public bool? myState;
            public bool myDesiredState;
            public Command MyDesiredCommand => myDesiredState ? Command.WILL : Command.WONT;
            public int myRequestCount;
            public bool? clientState;
            public Command ClientDesiredCommand => clientDesiredState switch
            {
                true => Command.DO,
                false => Command.DONT,
                _ => Command.NOP
            };
            public bool? clientDesiredState;
            public int clientRequestCount;
        }

        private readonly List<TelnetOption> telnetOptions = new List<TelnetOption>
        {
            new TelnetOption(Option.Echo, true, false), // Server controls what is displayed on screen
            new TelnetOption(Option.SuppressGoAhead, true, true), // Full duplex
            new TelnetOption(Option.LineMode, false, false), // Server edits input line (tab?)
            new TelnetOption(Option.BinaryTransmission, true),
            new TelnetOption(Option.NegotiateAboutWindowSize, false, true), // I won't, you let me know
            new TelnetOption(Option.TerminalType, false),
            new TelnetOption(Option.TerminalSpeed, false),
        };

        public TelnetTerminal(TcpClient tcpClient)
        {
            this.tcpClient = tcpClient;
            netStream = tcpClient.GetStream();
            Out = new StreamWriter(netStream, Encoding.UTF8) { AutoFlush = false };
            PageSize = 32;
            lineWidth = Terminal.DefaultLineWidth;
            Out.NewLine = "\r\n";            
            tcpClient.NoDelay = true;
            tcpClient.SendBufferSize = 1024;

            foreach (var telOpt in telnetOptions)
            {
                SendCode(telOpt.MyDesiredCommand, telOpt.opt); // I Will-Wont
                var clientCommand = telOpt.ClientDesiredCommand;
                if (clientCommand != Command.NOP)
                    SendCode(clientCommand, telOpt.opt);
            }
        }

        private void SendCode(Command code, Option feature)
        {
            Span<byte> outStream = stackalloc byte[3];
            outStream[0] = (byte)Command.IAC;
            outStream[1] = (byte)code;
            outStream[2] = (byte)feature;
            
            try
            {
                netStream.Write(outStream);
            }
            catch (ObjectDisposedException)
            {
                throw new TerminalException(TerminalException.CodeType.ClientDisconnected);
            }
            catch (IOException ioEx) when (IsDisconnect(ioEx))
            {
                throw new TerminalException(TerminalException.CodeType.ClientDisconnected);
            }
            
            Debug.Write($"[SERVER: {code} {feature}] ");
        }

        public string Id => Connected ? tcpClient.Client.RemoteEndPoint?.ToString() ?? "Disconnected" : "Disconnected";

        public bool Connected => tcpClient.Connected;

        public void Close()
        {
            try { Out?.Flush(); } 
            catch { }
            try { Out?.Dispose(); } 
            catch { }
            try { tcpClient?.Dispose(); } 
            catch { }
        }

        private void FillInputBuffer()
        {
            if (inputPos >= inputLen)
            {
                try
                {
                    inputLen = netStream.Read(inputBytes, 0, inputBytes.Length);
                }
                catch (ObjectDisposedException)
                {
                    throw new TerminalException(TerminalException.CodeType.ClientDisconnected);
                }
                catch (IOException ioEx) when (IsDisconnect(ioEx))
                {
                    throw new TerminalException(TerminalException.CodeType.ClientDisconnected);
                }
                
                if (inputLen == 0)
                    throw new TerminalException(TerminalException.CodeType.ClientDisconnected);
                
                inputPos = 0;
            }
        }

        private static bool IsDisconnect(IOException ioEx) =>
            ioEx.InnerException is SocketException socketEx && socketEx.SocketErrorCode switch
            {
                SocketError.ConnectionReset or
                SocketError.ConnectionAborted or
                SocketError.Shutdown or
                SocketError.OperationAborted or
                SocketError.NotConnected or
                SocketError.TimedOut => true,
                _ => false
            };

        private byte PeekByteFromNetworkStream()
        {
            FillInputBuffer();
            return inputBytes[inputPos];
        }

        private byte GetByteFromNetworkStream()
        {
            FillInputBuffer();
            return inputBytes[inputPos++];
        }

        private void ProcessTelnetCommands()
        {
            int next = PeekByteFromNetworkStream();
            Debug.Assert(next == (byte)Command.IAC, "We should not be here if telnet command not pending");
            
            while (next == (byte)Command.IAC)
            {
                var iac = (Command)GetByteFromNetworkStream();
                var cmd = (Command)GetByteFromNetworkStream();
                var opt = Option.NONE;
                
                switch (cmd)
                {
                    case Command.DO:
                    case Command.DONT:
                    case Command.WILL:
                    case Command.WONT:
                        opt = (Option)GetByteFromNetworkStream();
                        Debug.Write($"[CLIENT: {cmd} {opt}] ");
                        
                        var telOpt = telnetOptions.FirstOrDefault(topt => topt.opt == opt);
                        if (telOpt is not null)
                        {
                            if (cmd is Command.DO or Command.DONT)
                            {
                                telOpt.myState = cmd == Command.DO;
                                if (telOpt.MyCommandConflictsDesired(cmd))
                                    SendCode(telOpt.MyDesiredCommand, opt);
                            }
                            if (cmd is Command.WILL or Command.WONT)
                            {
                                telOpt.clientState = cmd == Command.WILL;
                                if (telOpt.ClientCommandConflictsDesired(cmd))
                                    SendCode(telOpt.ClientDesiredCommand, opt);
                            }
                        }
                        break;

                    case Command.SB:
                        ProcessSubnegotiation();
                        break;
                }
                
                next = PeekByteFromNetworkStream();
            }
        }

        private void ProcessSubnegotiation()
        {
            var opt = (Option)GetByteFromNetworkStream();
            var negotiationStr = new List<byte>();
            
            while (Connected)
            {
                byte b = GetByteFromNetworkStream();
                if (b == (byte)Command.IAC && PeekByteFromNetworkStream() == (byte)Command.SE)
                {
                    GetByteFromNetworkStream(); // pop peeked SE
                    
                    switch (opt)
                    {
                        case Option.NegotiateAboutWindowSize when negotiationStr.Count >= 4:
                            lineWidth = negotiationStr[1] + 256 * negotiationStr[0];
                            PageSize = (negotiationStr[3] + 256 * negotiationStr[2]) - 1;
                            Trace.TraceInformation($"NAWS LineWidth={lineWidth}, PageSize={PageSize}");
                            break;

                        default:
                            Trace.TraceWarning($"TELNET Unsupported negotiation type {opt}");
                            break;
                    }
                    break;
                }
                negotiationStr.Add(b);
            }
        }

        protected override char ReadChar()
        {
            while (true)
            {
                byte peekChr = PeekByteFromNetworkStream();
                if (peekChr == (byte)Command.IAC)
                {
                    ProcessTelnetCommands();
                    continue;
                }
                // UTF decode the next character, which may be multiple bytes
                char[] chars = Encoding.UTF8.GetChars(inputBytes, inputPos, inputLen - inputPos);
                if (chars.Length == 0)
                    return NulChar;

                int len = Encoding.UTF8.GetByteCount([chars[0]]);
                inputPos += len;
                return chars[0];
            }
        }

        /// <summary>
        /// Telnet implementation that detects arrow key sequences (ESC [ A/B/C/D)
        /// and Home/End sequences (ESC [ H/F or ESC [ 1/4 ~)
        /// A=Up, B=Down, C=Right, D=Left, H=Home, F=End
        /// </summary>
        protected override KeyInfo ReadKeyInfo()
        {
            var chr = ReadChar();
            
            // Handle carriage return
            if (chr == CR)
            {
               if (PeekByteFromNetworkStream() == LF)
                    GetByteFromNetworkStream();
                return new KeyInfo { Char = CR };
            }

            // Check for escape sequence (arrow keys, home, end)
            if (chr == Del)
            {
                return new KeyInfo { Key = ConsoleKey.Backspace };
            }

            if (chr == Esc)
            {
                chr = ReadChar();

                
                if (chr == '[')
                {
                    chr = ReadChar();
                    
                    // Handle standard arrow keys and Home/End
                    if (chr is >= 'A' and <= 'F')
                    {
                        return chr switch
                        {
                            'A' => new KeyInfo { Key = ConsoleKey.UpArrow },
                            'B' => new KeyInfo { Key = ConsoleKey.DownArrow },
                            'C' => new KeyInfo { Key = ConsoleKey.RightArrow },
                            'D' => new KeyInfo { Key = ConsoleKey.LeftArrow },
                            'H' => new KeyInfo { Key = ConsoleKey.Home },
                            'F' => new KeyInfo { Key = ConsoleKey.End },
                            _ => new KeyInfo { }
                        };
                    }
                    
                    // Handle tilde sequences: ESC [ 1 ~ (Home), ESC [ 4 ~ (End), etc.
                    if (chr is >='1' and <= '4')
                    {                        
                        if (ReadChar() == '~')
                        {
                            return chr switch
                            {
                                '1' => new KeyInfo { Key = ConsoleKey.Home },
                                // '2' => new KeyInfo { Key = ConsoleKey.Insert },
                                '3' => new KeyInfo { Key = ConsoleKey.Delete },
                                '4' => new KeyInfo { Key = ConsoleKey.End },
                                _ => new KeyInfo { }
                            };
                        }
                    }
                }
            }

            // Regular character            
            return new KeyInfo { Char = chr };
        }

        public override void ClearScreen() => SendANSI('J', "2");


        public void ClearLine() => SendANSI('K', "2");

        private readonly byte[] inputBytes = new byte[256];
        private int inputLen;
        private int inputPos;
        private readonly TcpClient tcpClient;
        private readonly NetworkStream netStream;
        private int lineWidth;
    }
}