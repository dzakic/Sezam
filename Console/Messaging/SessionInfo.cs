using System;
using System.Text.Json.Serialization;
using Sezam.Data;

namespace Sezam
{
    /// <summary>
    /// Serializable session information for distribution across nodes.
    /// Contains only public information that can be shared between nodes.
    /// </summary>
    public class SessionInfo
    {
        [JsonPropertyName("id")]
        public Guid Id { get; set; }

        [JsonPropertyName("username")]
        public string Username { get; set; }

        [JsonPropertyName("connectTime")]
        public DateTime ConnectTime { get; set; }

        [JsonPropertyName("loginTime")]
        public DateTime LoginTime { get; set; }

        [JsonPropertyName("nodeId")]
        public string NodeId { get; set; }

        [JsonPropertyName("terminalId")]
        public string TerminalId { get; set; }

        /// <summary>
        /// Creates a SessionInfo from an ISession
        /// </summary>
        public static SessionInfo FromSession(ISession session, string nodeId, string terminalId)
        {
            if (session == null)
                throw new ArgumentNullException(nameof(session));

            return new SessionInfo
            {
                Id = session.Id,
                Username = session.Username,
                ConnectTime = session.ConnectTime,
                LoginTime = session.LoginTime,
                NodeId = nodeId,
                TerminalId = terminalId
            };
        }

        /// <summary>
        /// Creates a deep copy of this SessionInfo
        /// </summary>
        public SessionInfo Clone()
        {
            return new SessionInfo
            {
                Id = Id,
                Username = Username,
                ConnectTime = ConnectTime,
                LoginTime = LoginTime,
                NodeId = NodeId,
                TerminalId = TerminalId
            };
        }

        public override string ToString()
        {
            return $"{Username}@{NodeId} (connected {ConnectTime:HH:mm:ss})";
        }
    }
}
