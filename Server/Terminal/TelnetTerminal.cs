using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Diagnostics;
using System.Threading.Tasks;

namespace Sezam
{
   public class TelnetTerminal : Terminal, ITerminal
   {

      // Telnet Protocol: http://support2.microsoft.com/kb/231866

      enum Command
      {
         // interpret as command
         IAC = 255,
         DONT = 254,
         DO = 253,
         WONT = 252,
         WILL = 251,
         // subnegotiatoin begin
         SB = 250,
         // subnegotiatoin end
         SE = 240,
         NOP = 241,
         BRK = 243,
         // are you there
         AYT = 246,
         // erase line
         EL = 248,
      }

      enum Option
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
         LineMode = 34,
         // 32, 39 ?
      }

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
         SendCode(Command.DONT, Option.Echo);
         SendCode(Command.WILL, Option.Echo);
         SendCode(Command.DO, Option.NegotiateAboutWindowSize);
         SendCode(Command.DO, Option.TerminalType);
         SendCode(Command.DONT, Option.LineMode);
         SendCode(Command.WILL, Option.SuppressGoAhead);
         SendCode(Command.DO, Option.SuppressGoAhead);
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
      }

      public string Id { get { return Connected ? tcpClient.Client.RemoteEndPoint.ToString() : "Disconnected"; } }

      public bool Connected {
         get { return tcpClient.Connected; }
      }

      public void Close()
      {
         if (Connected)
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
               Debug.Write("CLIENT " + cmd.ToString() + " " + opt.ToString() + ", ");
               // TODO Maintain Telnet option status with will/do/wont/dont
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
                     PageSize = negotiationStr[3] + 256 * negotiationStr[2];
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
         if (peekByteFromNetworkStream() == (byte)Command.IAC)
            processTelnetCommands();
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
         string paramsStr = string.Empty;
         if (parameters.Count() > 0)
         {
            int last = parameters.Count() - 1;
            for (int i = 0; i < last; i++)
               paramsStr += parameters[i] + ",";
            paramsStr += parameters[last];
         }
         Out.Write((char)27 + "[" + paramsStr + code);
      }

      public override void ClearScreen()
      {
         sendANSI('J', "2");
      }

      public override void ClearToEOL()
      {
         sendANSI('K');
      }

      private byte[] inputBytes = new byte[256];
      private int inputLen = 0;
      private int inputPos = 0;
      private TcpClient tcpClient;
      private NetworkStream netStream;
   }
}