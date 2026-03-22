using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Sezam.Data;
using StackExchange.Redis;

namespace Sezam
{
    /// <summary>
    /// Broadcasts messages and session information to other nodes in a swarm via Redis Pub/Sub.
    /// Falls back to local-only operation if Redis is unavailable.
    /// 
    /// Session event protocol on the <c>sezam:sessions</c> channel:
    /// <list type="bullet">
    ///   <item><c>UPDATE</c>  – full <see cref="SessionInfo"/> snapshot (login, state change, etc.)</item>
    ///   <item><c>LEAVE</c>   – session GUID only; receivers remove from cache</item>
    ///   <item><c>DISCOVER</c> – new node requests all remote sessions</item>
    ///   <item><c>DISCOVER_RESPONSE</c> – existing node responds with its local sessions</item>
    /// </list>
    /// </summary>
    public class MessageBroadcaster : IAsyncDisposable
    {
        private IConnectionMultiplexer _redis;
        private ISubscriber _subscriber;
        private const string MESSAGE_CHANNEL = "sezam:broadcast";
        private const string SESSION_CHANNEL = "sezam:sessions";
        private readonly string _localNodeId = Guid.NewGuid().ToString();
        private bool _redisAvailable;
        private ILogger _logger = NullLogger.Instance;

        // Cache of sessions from remote nodes
        private readonly ConcurrentDictionary<Guid, SessionInfo> _remoteSessionCache = new();

        public bool IsRedisConnected => _redisAvailable && _redis?.IsConnected == true;

        /// <summary>
        /// Unique identifier for this node instance.
        /// </summary>
        public string LocalNodeId => _localNodeId;

        /// <summary>
        /// Initialize the broadcaster and attempt to connect to Redis.
        /// After subscribing, sends a DISCOVER request so existing nodes report their sessions.
        /// </summary>
        public async Task InitializeAsync(string redisConnectionString = "localhost:6379")
        {
            _logger = (ILogger)Data.Store.LoggerFactory?.CreateLogger<MessageBroadcaster>() ?? NullLogger.Instance;

            try
            {
                if (string.IsNullOrWhiteSpace(redisConnectionString))
                {
                    _redisAvailable = false;
                    return;
                }

                var options = ConfigurationOptions.Parse(redisConnectionString);
                options.AbortOnConnectFail = false;
                options.ConnectTimeout = 2000;
                options.SyncTimeout = 2000;

                _redis = await ConnectionMultiplexer.ConnectAsync(options);

                if (!_redis.IsConnected)
                {
                    _redisAvailable = false;
                    return;
                }

                _subscriber = _redis.GetSubscriber();
                _redisAvailable = true;

                // Subscribe to incoming messages from other nodes
                await _subscriber.SubscribeAsync(RedisChannel.Literal(MESSAGE_CHANNEL), async (channel, value) =>
                {
                    var raw = value.ToString();
                    // Format: {nodeId}|{envelope}
                    var pipeIndex = raw.IndexOf('|');
                    if (pipeIndex < 0) return;

                    var senderId = raw[..pipeIndex];
                    if (senderId == _localNodeId) return;

                    var envelope = raw[(pipeIndex + 1)..];
                    HandleMessageEnvelope(envelope);
                });

                // Subscribe to session events from other nodes
                await _subscriber.SubscribeAsync(RedisChannel.Literal(SESSION_CHANNEL), async (channel, value) =>
                {
                    await HandleSessionEvent(value.ToString());
                });

                // Ask existing nodes to report their sessions
                await PublishSessionEvent("DISCOVER:");

                _logger.LogInformation("MessageBroadcaster initialized, DISCOVER sent (node {NodeId})", _localNodeId[..8]);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Redis connection failed");
                _redisAvailable = false;
            }
        }

        private async Task HandleSessionEvent(string message)
        {
            try
            {
                var parts = message.Split('|', 2);
                if (parts.Length != 2)
                    return;

                var senderId = parts[0];
                if (senderId == _localNodeId)
                    return;

                var colonIndex = parts[1].IndexOf(':');
                if (colonIndex < 0)
                    return;

                var eventType = parts[1][..colonIndex];
                var eventData = parts[1][(colonIndex + 1)..];

                switch (eventType)
                {
                    case "UPDATE":
                        HandleUpdate(eventData);
                        break;

                    case "LEAVE":
                        HandleLeave(eventData);
                        break;

                    case "DISCOVER":
                        await HandleDiscoverRequest();
                        break;

                    case "DISCOVER_RESPONSE":
                        HandleDiscoverResponse(eventData);
                        break;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error processing session event");
            }
        }

        private void HandleUpdate(string json)
        {
            var sessionInfo = JsonSerializer.Deserialize<SessionInfo>(json);
            if (sessionInfo != null)
            {
                sessionInfo.IsLocal = false;
                _remoteSessionCache[sessionInfo.Id] = sessionInfo;
                _logger.LogDebug("Session UPDATE: {Username} on node {NodeId}", sessionInfo.Username, sessionInfo.NodeId?[..8]);
            }
        }

        private void HandleLeave(string data)
        {
            if (Guid.TryParse(data, out var sessionId))
            {
                _remoteSessionCache.TryRemove(sessionId, out var removed);
                _logger.LogDebug("Session LEAVE: {SessionId} ({Username})", sessionId, removed?.Username);
            }
        }

        /// <summary>
        /// Another node asked to discover sessions. Respond with all our local sessions.
        /// </summary>
        private async Task HandleDiscoverRequest()
        {
            var localSessions = Data.Store.Sessions.Values
                .Select(s => SessionInfo.FromSession(s, _localNodeId, null))
                .ToList();

            if (localSessions.Count == 0)
                return;

            var json = JsonSerializer.Serialize(localSessions);
            await PublishSessionEvent($"DISCOVER_RESPONSE:{json}");
            _logger.LogDebug("Responded to DISCOVER with {Count} local session(s)", localSessions.Count);
        }

        private void HandleDiscoverResponse(string json)
        {
            var sessions = JsonSerializer.Deserialize<List<SessionInfo>>(json);
            if (sessions == null)
                return;

            foreach (var s in sessions)
            {
                s.IsLocal = false;
                _remoteSessionCache[s.Id] = s;
            }
            _logger.LogDebug("DISCOVER_RESPONSE received: {Count} session(s) added", sessions.Count);
        }

        /// <summary>
        /// Handle a structured message envelope received from another node.
        /// Envelope formats:
        ///   BROADCAST:{from}:{message}
        ///   USER:{toUsername}:{from}:{message}
        ///   CHAT:{room}:{from}:{message}
        /// </summary>
        private void HandleMessageEnvelope(string envelope)
        {
            try
            {
                var colonIndex = envelope.IndexOf(':');
                if (colonIndex < 0) return;

                var type = envelope[..colonIndex];
                var payload = envelope[(colonIndex + 1)..];

                _logger.LogDebug("Received message envelope of type {Type} with payload: {Payload}", type, payload);

                switch (type)
                {
                    case "BROADCAST":
                    {
                        // payload = "{from}:*:{message}"
                        var parts = payload.Split(':', 3);
                        if (parts.Length == 3)
                            Data.Store.LocalBroadcast(parts[0], parts[1], parts[2]);
                        break;
                    }
                    case "USER":
                    {
                        // payload = "{from}:{to}:{message}"
                        var parts = payload.Split(':', 3);
                        if (parts.Length == 3)
                        {
                            var localSession = Data.Store.Sessions.Values
                                .FirstOrDefault(s => s.Username != null &&
                                    s.Username.Equals(parts[1], StringComparison.OrdinalIgnoreCase));
                            localSession?.Deliver(parts[0], parts[1], parts[2]);
                        }
                        break;
                    }
                    case "CHAT":
                    {
                        // payload = "{from}:{room}:{message}"
                        var parts = payload.Split(':', 3);
                        if (parts.Length == 3)
                        {
                            Data.Store.LocalBroadcast(parts[0], parts[1], parts[2]);
                        }
                        break;
                    }
                    default:
                        _logger.LogDebug("Unknown message envelope type: {Type}", type);
                        break;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error handling message envelope");
            }
        }

        /// <summary>
        /// Broadcast a message to all nodes in the swarm.
        /// </summary>
        public async Task BroadcastAsync(string message)
        {
            if (!IsRedisConnected)
                return;

            try
            {
                var fullMessage = $"{_localNodeId}|{message}";
                await _subscriber.PublishAsync(RedisChannel.Literal(MESSAGE_CHANNEL), fullMessage);
                _logger.LogInformation($"PublichAsync to channel:{MESSAGE_CHANNEL}, message: {fullMessage}");
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to broadcast message");
            }
        }

        /// <summary>
        /// Publish a full session snapshot (UPDATE) to all nodes.
        /// Called on login, state changes, or any session detail update.
        /// </summary>
        public async Task BroadcastSessionUpdateAsync(SessionInfo sessionInfo)
        {
            if (sessionInfo == null)
                throw new ArgumentNullException(nameof(sessionInfo));

            if (!IsRedisConnected)
                return;

            try
            {
                var json = JsonSerializer.Serialize(sessionInfo);
                await PublishSessionEvent($"UPDATE:{json}");
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to broadcast session update for {Username}", sessionInfo.Username);
            }
        }

        /// <summary>
        /// Broadcast session leave event to all nodes.
        /// </summary>
        public async Task BroadcastSessionLeaveAsync(Guid sessionId)
        {
            if (!IsRedisConnected)
                return;

            try
            {
                await PublishSessionEvent($"LEAVE:{sessionId}");
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to broadcast session leave for {SessionId}", sessionId);
            }
        }

        /// <summary>
        /// Get all remote sessions (from other nodes).
        /// </summary>
        public IEnumerable<SessionInfo> GetRemoteSessions()
        {
            return _remoteSessionCache.Values.ToList();
        }

        /// <summary>
        /// Get a specific remote session by ID.
        /// </summary>
        public SessionInfo GetRemoteSession(Guid sessionId)
        {
            _remoteSessionCache.TryGetValue(sessionId, out var sessionInfo);
            return sessionInfo;
        }

        /// <summary>
        /// Get count of remote sessions.
        /// </summary>
        public int GetRemoteSessionCount() => _remoteSessionCache.Count;

        private async Task PublishSessionEvent(string eventPayload)
        {
            var fullMessage = $"{_localNodeId}|{eventPayload}";
            await _subscriber.PublishAsync(RedisChannel.Literal(SESSION_CHANNEL), fullMessage);
        }

        public async ValueTask DisposeAsync()
        {
            if (_redis != null)
            {
                await _redis.CloseAsync();
                _redis.Dispose();
            }
        }
    }
}
