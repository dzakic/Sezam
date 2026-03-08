using System;
using System.Collections.Generic;
using System.Linq;
using Sezam.Data;

namespace Sezam
{
    /// <summary>
    /// Provides distributed session information across all nodes in the swarm.
    /// Combines local sessions (from current node) with remote sessions (from other nodes).
    /// </summary>
    public class DistributedSessionRegistry
    {
        private readonly MessageBroadcaster _broadcaster;

        public DistributedSessionRegistry(MessageBroadcaster broadcaster)
        {
            _broadcaster = broadcaster ?? throw new ArgumentNullException(nameof(broadcaster));
        }

        /// <summary>
        /// Get all sessions on this node (local sessions)
        /// </summary>
        public IEnumerable<ISession> GetLocalSessions()
        {
            return Data.Store.Sessions.Values.ToList();
        }

        /// <summary>
        /// Get all sessions from other nodes (remote sessions)
        /// </summary>
        public IEnumerable<SessionInfo> GetRemoteSessions()
        {
            return _broadcaster.GetRemoteSessions();
        }

        /// <summary>
        /// Get all sessions across all nodes (local + remote)
        /// </summary>
        public IEnumerable<SessionDetails> GetAllSessions()
        {
            var result = new List<SessionDetails>();

            // Add local sessions
            foreach (var session in GetLocalSessions())
            {
                result.Add(new SessionDetails
                {
                    Id = session.Id,
                    Username = session.Username,
                    ConnectTime = session.ConnectTime,
                    LoginTime = session.LoginTime,
                    NodeId = _broadcaster.LocalNodeId,
                    TerminalId = session is Session s ? s.terminal?.Id : "Unknown",
                    IsLocal = true
                });
            }

            // Add remote sessions
            foreach (var remote in GetRemoteSessions())
            {
                result.Add(new SessionDetails
                {
                    Id = remote.Id,
                    Username = remote.Username,
                    ConnectTime = remote.ConnectTime,
                    LoginTime = remote.LoginTime,
                    NodeId = remote.NodeId,
                    TerminalId = remote.TerminalId,
                    IsLocal = false
                });
            }

            return result;
        }

        /// <summary>
        /// Get count of sessions on this node
        /// </summary>
        public int GetLocalSessionCount() => GetLocalSessions().Count();

        /// <summary>
        /// Get count of sessions on other nodes
        /// </summary>
        public int GetRemoteSessionCount() => _broadcaster.GetRemoteSessionCount();

        /// <summary>
        /// Get total count of sessions across all nodes
        /// </summary>
        public int GetTotalSessionCount() => GetLocalSessionCount() + GetRemoteSessionCount();

        /// <summary>
        /// Check if a user is online (on any node)
        /// </summary>
        public bool IsUserOnline(string username)
        {
            if (string.IsNullOrEmpty(username))
                return false;

            // Check local sessions
            if (GetLocalSessions().Any(s => s.Username.Equals(username, StringComparison.OrdinalIgnoreCase)))
                return true;

            // Check remote sessions
            if (GetRemoteSessions().Any(s => s.Username.Equals(username, StringComparison.OrdinalIgnoreCase)))
                return true;

            return false;
        }

        /// <summary>
        /// Get session details by username (searches local and remote)
        /// </summary>
        public SessionDetails GetSessionByUsername(string username)
        {
            if (string.IsNullOrEmpty(username))
                return null;

            // Check local sessions
            var localSession = GetLocalSessions()
                .FirstOrDefault(s => s.Username.Equals(username, StringComparison.OrdinalIgnoreCase));
            if (localSession != null)
            {
                return new SessionDetails
                {
                    Id = localSession.Id,
                    Username = localSession.Username,
                    ConnectTime = localSession.ConnectTime,
                    LoginTime = localSession.LoginTime,
                    NodeId = _broadcaster.LocalNodeId,
                    TerminalId = localSession is Session s ? s.terminal?.Id : "Unknown",
                    IsLocal = true
                };
            }

            // Check remote sessions
            var remoteSession = GetRemoteSessions()
                .FirstOrDefault(s => s.Username.Equals(username, StringComparison.OrdinalIgnoreCase));
            if (remoteSession != null)
            {
                return new SessionDetails
                {
                    Id = remoteSession.Id,
                    Username = remoteSession.Username,
                    ConnectTime = remoteSession.ConnectTime,
                    LoginTime = remoteSession.LoginTime,
                    NodeId = remoteSession.NodeId,
                    TerminalId = remoteSession.TerminalId,
                    IsLocal = false
                };
            }

            return null;
        }

        /// <summary>
        /// Get session details by ID (searches local and remote)
        /// </summary>
        public SessionDetails GetSessionById(Guid sessionId)
        {
            // Check local sessions
            var localSession = GetLocalSessions()
                .FirstOrDefault(s => s.Id == sessionId);
            if (localSession != null)
            {
                return new SessionDetails
                {
                    Id = localSession.Id,
                    Username = localSession.Username,
                    ConnectTime = localSession.ConnectTime,
                    LoginTime = localSession.LoginTime,
                    NodeId = _broadcaster.LocalNodeId,
                    TerminalId = localSession is Session s ? s.terminal?.Id : "Unknown",
                    IsLocal = true
                };
            }

            // Check remote sessions
            var remoteSession = _broadcaster.GetRemoteSession(sessionId);
            if (remoteSession != null)
            {
                return new SessionDetails
                {
                    Id = remoteSession.Id,
                    Username = remoteSession.Username,
                    ConnectTime = remoteSession.ConnectTime,
                    LoginTime = remoteSession.LoginTime,
                    NodeId = remoteSession.NodeId,
                    TerminalId = remoteSession.TerminalId,
                    IsLocal = false
                };
            }

            return null;
        }

        /// <summary>
        /// Get list of online usernames
        /// </summary>
        public IEnumerable<string> GetOnlineUsernames()
        {
            var usernames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var session in GetLocalSessions())
                if (!string.IsNullOrEmpty(session.Username))
                    usernames.Add(session.Username);

            foreach (var session in GetRemoteSessions())
                if (!string.IsNullOrEmpty(session.Username))
                    usernames.Add(session.Username);

            return usernames.OrderBy(u => u);
        }

        /// <summary>
        /// Get sessions by node ID
        /// </summary>
        public IEnumerable<SessionDetails> GetSessionsByNode(string nodeId)
        {
            if (nodeId == _broadcaster.LocalNodeId)
            {
                return GetLocalSessions().Select(s => new SessionDetails
                {
                    Id = s.Id,
                    Username = s.Username,
                    ConnectTime = s.ConnectTime,
                    LoginTime = s.LoginTime,
                    NodeId = nodeId,
                    TerminalId = s is Session ss ? ss.terminal?.Id : "Unknown",
                    IsLocal = true
                });
            }
            else
            {
                return GetRemoteSessions()
                    .Where(s => s.NodeId == nodeId)
                    .Select(s => new SessionDetails
                    {
                        Id = s.Id,
                        Username = s.Username,
                        ConnectTime = s.ConnectTime,
                        LoginTime = s.LoginTime,
                        NodeId = s.NodeId,
                        TerminalId = s.TerminalId,
                        IsLocal = false
                    });
            }
        }

        /// <summary>
        /// Get summary of all nodes and their sessions
        /// </summary>
        public IEnumerable<NodeSummary> GetNodeSummaries()
        {
            var nodes = new Dictionary<string, NodeSummary>();

            // Add local node
            var localNode = new NodeSummary
            {
                NodeId = _broadcaster.LocalNodeId,
                IsLocal = true,
                SessionCount = GetLocalSessionCount()
            };
            nodes[_broadcaster.LocalNodeId] = localNode;

            // Add remote nodes
            var remoteNodes = GetRemoteSessions()
                .GroupBy(s => s.NodeId)
                .Select(g => new NodeSummary
                {
                    NodeId = g.Key,
                    IsLocal = false,
                    SessionCount = g.Count()
                });

            foreach (var node in remoteNodes)
            {
                nodes[node.NodeId] = node;
            }

            return nodes.Values.OrderBy(n => n.IsLocal ? 0 : 1);
        }
    }

    /// <summary>
    /// Complete session details across all nodes
    /// </summary>
    public class SessionDetails
    {
        public Guid Id { get; set; }
        public string Username { get; set; }
        public DateTime ConnectTime { get; set; }
        public DateTime LoginTime { get; set; }
        public string NodeId { get; set; }
        public string TerminalId { get; set; }
        public bool IsLocal { get; set; }

        public TimeSpan ConnectedDuration => DateTime.Now - ConnectTime;

        public override string ToString()
        {
            var location = IsLocal ? "local" : $"@{NodeId.Substring(0, 8)}";
            return $"{Username} {location} ({ConnectedDuration.TotalMinutes:F1}m)";
        }
    }

    /// <summary>
    /// Summary of a node's sessions
    /// </summary>
    public class NodeSummary
    {
        public string NodeId { get; set; }
        public bool IsLocal { get; set; }
        public int SessionCount { get; set; }

        public override string ToString()
        {
            var location = IsLocal ? "Local" : NodeId.Substring(0, 8);
            return $"{location}: {SessionCount} session(s)";
        }
    }
}
