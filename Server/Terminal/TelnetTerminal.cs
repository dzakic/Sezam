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

        class TelnetOption
        {

            const int MAXRETRY = 2;

            internal TelnetOption(Option code, bool myDesired, bool? clientDesired = null)
            {
                this.opt = code;
                this.myDesiredState = myDesired;
                this.clientDesiredState = clientDesired;
                myRequestCount = 0;
                clientRequestCount = 0;
            }
            
            public bool ClientCommandConflictsDesired(Command cmd)
            {
                if (clientDesiredState == null || clientRequestCount > MAXRETRY)
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
            public Command MyDesiredCommand { get { return myDesiredState ? Command.WILL : Command.WONT; } }
            public int myRequestCount;
            public bool? clientState;
            public Command ClientDesiredCommand { get { return clientDesiredState != null ? clientDesiredState.Value ? Command.DO : Command.DONT : Command.NOP; } }
            public bool? clientDesiredState;
            public int clientRequestCount;
        }

        List<TelnetOption> telnetOptions = new List<TelnetOption>
            {
                new TelnetOption(Option.Echo, true, false), // Sezam controls what is displayed on screen
                new TelnetOption(Option.SuppressGoAhead, true, true), // Full duplex
                new TelnetOption(Option.LineMode, false, false), // Sezam edits input line (tab?)
                new TelnetOption(Option.BinaryTransmission, true), // Sezam edits input line (tab?)
                new TelnetOption(Option.NegotiateAboutWindowSize, false, true), // I won't, you please do let me know about window resize
                new TelnetOption(Option.TerminalType, false), 
                new TelnetOption(Option.TerminalSpeed, false),
            };

        public TelnetTerminal(TcpClient tcpClient)
        {
            this.tcpClient = tcpClient;
            netStream = tcpClient.GetStream();
            // In = new StreamReader(netStream, true);
            Out = new StreamWriter(netStream, Encoding.UTF8) { AutoFlush = false };
            PageSize = 32;
            Out.NewLine = "\r\n";            
            tcpClient.NoDelay = true;
            tcpClient.SendBufferSize = 256;

            foreach (TelnetOption telOpt in telnetOptions)
            {
                SendCode(telOpt.MyDesiredCommand, telOpt.opt); // I Will-Wont
                var clientCommand = telOpt.ClientDesiredCommand;
                if (clientCommand != Command.NOP)
                    SendCode(clientCommand, telOpt.opt); // You Do-Dont
            }

            // Trace.TraceInformation("TCPClient recv buffer size: {0}", tcpClient.ReceiveBufferSize);
            // Trace.TraceInformation("TCPClient send buffer size: {0}", tcpClient.SendBufferSize);
        }

        private void SendCode(Command code, Option feature)
        {
            byte[] outStream = new byte[3];
            outStream[0] = (byte)Command.IAC;
            outStream[1] = (byte)code;
            outStream[2] = (byte)feature;
            netStream.Write(outStream, 0, outStream.Length);
            Debug.Write("[SERVER: " + code.ToString() + " " + feature.ToString() + "] ");
        }

        public string Id { get { return Connected ? tcpClient.Client.RemoteEndPoint.ToString() : "Disconnected"; } }

        public bool Connected
        {
            get { return tcpClient.Connected; }
        }

        public void Close()
        {
            Out.Flush();
            if (tcpClient != null)
                tcpClient.Close();
        }

        private void fillInputBuffer()
        {
            if (inputPos >= inputLen)
            {
                inputLen = netStream.Read(inputBytes, 0, inputBytes.Length);
                if (inputLen == 0)
                    throw new TerminalException(TerminalException.Code.ClientDisconnected);
                inputPos = 0;
            }
        }

        private byte peekByteFromNetworkStream()
        {
            fillInputBuffer();
            return inputBytes[inputPos];
        }

        private byte getByteFromNetworkStream()
        {
            fillInputBuffer();
            return inputBytes[inputPos++];
        }

    // Array of states. Count sent requests, give up after MAX(3?)
    //    { [Option, desiredState] }
    // if command in [do, dont]
    //    if (requested == desired) send cfm, else request(desired)
    // if command in (will, wont)
    //    if (confirmation != desired) send request(desired) else silent

    private void processTelnetCommands()
        {
            int next = peekByteFromNetworkStream();
            Debug.Assert(next == (byte)Command.IAC, "We should not be here if telnet command not pending");
            while (next == (byte)Command.IAC)
            {
                Command iac = (Command)getByteFromNetworkStream();
                Command cmd = (Command)getByteFromNetworkStream();
                Option opt = Option.NONE;
                switch (cmd)
                {
                    case Command.DO:
                    case Command.DONT:
                    case Command.WILL:
                    case Command.WONT:
                        opt = (Option)getByteFromNetworkStream();
                        Debug.Write("[CLIENT: " + cmd.ToString() + " " + opt.ToString() + "] ");
                        TelnetOption telOpt = telnetOptions.Where(topt => topt.opt == opt).FirstOrDefault();
                        if (telOpt != null)
                        {
                            if (cmd == Command.DO || cmd == Command.DONT)
                            {
                                telOpt.myState = cmd == Command.DO;
                                if (telOpt.MyCommandConflictsDesired(cmd))
                                {
                                    SendCode(telOpt.MyDesiredCommand, opt);
                                }
                            }
                            if (cmd == Command.WILL || cmd == Command.WONT)
                            {
                                telOpt.clientState = cmd == Command.WILL;
                                if (telOpt.ClientCommandConflictsDesired(cmd))
                                {
                                    SendCode(telOpt.ClientDesiredCommand, opt);
                                }
                            }
                        }
                        break;

                    case Command.SB:
                        processSubnegotiation();
                        break;

                    default:
                        break;
                }
                next = peekByteFromNetworkStream();
            }
        }

        private void processSubnegotiation()
        {
            Option opt = (Option)getByteFromNetworkStream();
            List<byte> negotiationStr = new List<byte>();
            while (Connected)
            {
                byte b = getByteFromNetworkStream();
                if (b == (byte)Command.IAC && peekByteFromNetworkStream() == (byte)Command.SE)
                {
                    b = getByteFromNetworkStream(); // pop peeked SE
                    Trace.TraceInformation("TELNET Got SB " + opt.ToString() + " " + BitConverter.ToString(negotiationStr.ToArray()) + " SE.");
                    switch (opt)
                    {
                        case Option.NegotiateAboutWindowSize:
                            PageSize = (negotiationStr[3] + 256 * negotiationStr[2]) - 1;
                            Trace.TraceInformation("NAWS PageSize=" + PageSize.ToString());
                            break;

                        default:
                            Trace.TraceWarning("TELNET Unsupported negotiation type " + opt.ToString());
                            break;
                    }
                    break;
                }
                negotiationStr.Add(b);
            }
            return;
        }

        protected override char ReadChar()
        {
            byte peekChr = peekByteFromNetworkStream();
            switch (peekChr)
            {
                case (byte)Command.IAC:
                    processTelnetCommands();
                    break;
                case 13:
                    getByteFromNetworkStream();
                    if (peekByteFromNetworkStream() == 10)
                        getByteFromNetworkStream();
                    return '\r';
            }
            // TODO Is it excessive to decode all buffered chars?
            char[] chars = Encoding.UTF8.GetChars(inputBytes, inputPos, inputLen - inputPos);
            if (chars.Count() == 0)
                return (char)0;
            char[] char1 = new char[1] { chars[0] };
            int len = Encoding.UTF8.GetByteCount(char1);
            inputPos += len;
            return chars[0];
        }

        private void sendANSI(char code, params string[] parameters)
        {
            const char Esc = (char)27;
            Out.Write(Esc + "[" + string.Join(";", parameters) + code);
        }

        public override void ClearScreen()
        {
            sendANSI('J', "2");
        }

        public override void ClearToEOL()
        {
            sendANSI('K');
        }

        public void ClearLine()
        {
            sendANSI('K', "2");
        }

        private byte[] inputBytes = new byte[256];
        private int inputLen = 0;
        private int inputPos = 0;
        private TcpClient tcpClient;
        private NetworkStream netStream;
    }
}