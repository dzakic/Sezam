using System;
using System.Collections.Generic;
using System.Linq;
using Sezam.Data;

namespace Sezam
{
    /// <summary>
    /// Provides a unified view of sessions across all nodes in the swarm.
    /// Combines local sessions (current node) with remote sessions (other nodes via Redis).
    /// </summary>
    public class DistributedSessionRegistry
    {
        private readonly MessageBroadcaster _broadcaster;

        public DistributedSessionRegistry(MessageBroadcaster broadcaster)
        {
            _broadcaster = broadcaster ?? throw new ArgumentNullException(nameof(broadcaster));
        }

        /// <summary>
        /// Build a <see cref="SessionInfo"/> from a local <see cref="ISession"/>.
        /// </summary>
        private SessionInfo ToSessionInfo(ISession session)
        {
            return SessionInfo.FromSession(session, _broadcaster.LocalNodeId, null);
        }

        /// <summary>
        /// Mark a remote <see cref="SessionInfo"/> as non-local.
        /// The objects coming from the broadcaster cache already have the right fields;
        /// we just stamp IsLocal = false for callers that care.
        /// </summary>
        private static SessionInfo AsRemote(SessionInfo remote)
        {
            remote.IsLocal = false;
            return remote;
        }

        /// <summary>
        /// Get all sessions on this node as <see cref="SessionInfo"/>.
        /// </summary>
        public IEnumerable<SessionInfo> GetLocalSessions()
        {
            return Data.Store.Sessions.Values.Select(ToSessionInfo).ToList();
        }

        /// <summary>
        /// Get all sessions from other nodes.
        /// </summary>
        public IEnumerable<SessionInfo> GetRemoteSessions()
        {
            return _broadcaster.GetRemoteSessions().Select(AsRemote).ToList();
        }

        /// <summary>
        /// Get all sessions across all nodes (local + remote).
        /// </summary>
        public IEnumerable<SessionInfo> GetAllSessions()
        {
            return GetLocalSessions().Concat(GetRemoteSessions());
        }

        public int GetLocalSessionCount() => Data.Store.Sessions.Count;

        public int GetRemoteSessionCount() => _broadcaster.GetRemoteSessionCount();

        public int GetTotalSessionCount() => GetLocalSessionCount() + GetRemoteSessionCount();

        /// <summary>
        /// Check if a user is online on any node.
        /// </summary>
        public bool IsUserOnline(string username)
        {
            if (string.IsNullOrEmpty(username))
                return false;

            return GetAllSessions().Any(s =>
                s.Username != null && s.Username.Equals(username, StringComparison.OrdinalIgnoreCase));
        }

        /// <summary>
        /// Find a session by username (searches local first, then remote).
        /// </summary>
        public SessionInfo GetSessionByUsername(string username)
        {
            if (string.IsNullOrEmpty(username))
                return null;

            return GetAllSessions().FirstOrDefault(s =>
                s.Username != null && s.Username.Equals(username, StringComparison.OrdinalIgnoreCase));
        }

        /// <summary>
        /// Find a session by ID (searches local first, then remote).
        /// </summary>
        public SessionInfo GetSessionById(Guid sessionId)
        {
            return GetAllSessions().FirstOrDefault(s => s.Id == sessionId);
        }

        /// <summary>
        /// Get sorted list of online usernames across all nodes.
        /// </summary>
        public IEnumerable<string> GetOnlineUsernames()
        {
            return GetAllSessions()
                .Where(s => !string.IsNullOrEmpty(s.Username))
                .Select(s => s.Username)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(u => u);
        }

        /// <summary>
        /// Get sessions belonging to a specific node.
        /// </summary>
        public IEnumerable<SessionInfo> GetSessionsByNode(string nodeId)
        {
            return nodeId == _broadcaster.LocalNodeId
                ? GetLocalSessions()
                : GetRemoteSessions().Where(s => s.NodeId == nodeId);
        }

        /// <summary>
        /// Get summary of all nodes and their session counts.
        /// </summary>
        public IEnumerable<NodeSummary> GetNodeSummaries()
        {
            var nodes = new Dictionary<string, NodeSummary>
            {
                [_broadcaster.LocalNodeId] = new NodeSummary
                {
                    NodeId = _broadcaster.LocalNodeId,
                    IsLocal = true,
                    SessionCount = GetLocalSessionCount()
                }
            };

            foreach (var group in GetRemoteSessions().GroupBy(s => s.NodeId))
            {
                nodes[group.Key] = new NodeSummary
                {
                    NodeId = group.Key,
                    IsLocal = false,
                    SessionCount = group.Count()
                };
            }

            return nodes.Values.OrderBy(n => n.IsLocal ? 0 : 1);
        }
    }

    /// <summary>
    /// Summary of a node's sessions.
    /// </summary>
    public class NodeSummary
    {
        public string NodeId { get; set; }
        public bool IsLocal { get; set; }
        public int SessionCount { get; set; }

        public override string ToString()
        {
            var location = IsLocal ? "Local" : NodeId[..Math.Min(4, NodeId.Length)];
            return $"{location}: {SessionCount} session(s)";
        }
    }
}
