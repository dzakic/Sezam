using Sezam.Data;
using System;
using System.Text.Json.Serialization;

namespace Sezam
{
    /// <summary>
    /// Universal session descriptor used for local display, remote transport, and registry queries.
    /// Serializable via System.Text.Json for Redis distribution between nodes.
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
        /// Current user state (e.g. "CHAT", "TRANSFER", "READ"). Null means idle/command prompt.
        /// </summary>
        [JsonPropertyName("state")]
        public string State { get; set; }

        /// <summary>
        /// True when this session lives on the current node. Not serialized — computed locally.
        /// </summary>
        [JsonIgnore]
        public bool IsLocal { get; set; }

        [JsonIgnore]
        public TimeSpan ConnectedDuration => DateTime.Now - ConnectTime;

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
                TerminalId = terminalId,
                IsLocal = true
            };
        }

        public override string ToString()
        {
            var location = IsLocal ? "local" : $"@{NodeId?[..Math.Min(8, NodeId.Length)]}";
            return $"{Username} {location} ({ConnectedDuration.TotalMinutes:F1}m)";
        }
    }
}
