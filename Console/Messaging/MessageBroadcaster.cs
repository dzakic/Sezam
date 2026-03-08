using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using StackExchange.Redis;

namespace Sezam
{
    /// <summary>
    /// Broadcasts messages and session information to other nodes in a swarm via Redis Pub/Sub.
    /// Falls back to local-only operation if Redis is unavailable.
    /// </summary>
    public class MessageBroadcaster : IAsyncDisposable
    {
        private IConnectionMultiplexer _redis;
        private ISubscriber _subscriber;
        private const string MESSAGE_CHANNEL = "sezam:broadcast";
        private const string SESSION_CHANNEL = "sezam:sessions";
        private readonly string _localNodeId = Guid.NewGuid().ToString();
        private Func<string, Task> _onMessageReceived;
        private Func<SessionInfo, Task> _onSessionJoined;
        private Func<Guid, Task> _onSessionLeft;
        private bool _redisAvailable;

        // Local cache of sessions from all nodes
        private readonly ConcurrentDictionary<Guid, SessionInfo> _remoteSessionCache = new();

        public bool IsRedisConnected => _redisAvailable && _redis?.IsConnected == true;

        /// <summary>
        /// Get the local node ID (unique per instance)
        /// </summary>
        public string LocalNodeId => _localNodeId;

        /// <summary>
        /// Initialize the broadcaster and attempt to connect to Redis.
        /// If Redis is unavailable, it will operate in local-only mode.
        /// </summary>
        public async Task InitializeAsync(string redisConnectionString = "localhost:6379")
        {
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
                    var message = value.ToString();
                    if (!message.StartsWith(_localNodeId)) // Ignore our own messages
                    {
                        _onMessageReceived?.Invoke(message);
                    }
                });

                // Subscribe to session events from other nodes
                await _subscriber.SubscribeAsync(RedisChannel.Literal(SESSION_CHANNEL), async (channel, value) =>
                {
                    var message = value.ToString();
                    try
                    {
                        var parts = message.Split('|', 2);
                        if (parts.Length != 2)
                            return;

                        var senderId = parts[0];
                        if (senderId == _localNodeId)
                            return; // Ignore our own messages

                        var eventType = parts[1].Split(':', 2)[0];
                        var eventData = parts[1].Substring(eventType.Length + 1);

                        if (eventType == "JOIN")
                        {
                            var sessionInfo = JsonSerializer.Deserialize<SessionInfo>(eventData);
                            if (sessionInfo != null)
                            {
                                _remoteSessionCache[sessionInfo.Id] = sessionInfo;
                                _onSessionJoined?.Invoke(sessionInfo);
                            }
                        }
                        else if (eventType == "LEAVE")
                        {
                            if (Guid.TryParse(eventData, out var sessionId))
                            {
                                _remoteSessionCache.TryRemove(sessionId, out _);
                                _onSessionLeft?.Invoke(sessionId);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine($"Error processing session event: {ex.Message}");
                    }
                });
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Redis connection failed: {ex.Message}");
                _redisAvailable = false;
            }
        }

        /// <summary>
        /// Register callback for when messages arrive from other nodes
        /// </summary>
        public void OnMessageReceived(Func<string, Task> handler)
        {
            _onMessageReceived = handler;
        }

        /// <summary>
        /// Register callback for when a session joins on another node
        /// </summary>
        public void OnSessionJoined(Func<SessionInfo, Task> handler)
        {
            _onSessionJoined = handler;
        }

        /// <summary>
        /// Register callback for when a session leaves on another node
        /// </summary>
        public void OnSessionLeft(Func<Guid, Task> handler)
        {
            _onSessionLeft = handler;
        }

        /// <summary>
        /// Broadcast a message to all nodes in the swarm
        /// </summary>
        public async Task BroadcastAsync(string message)
        {
            if (!IsRedisConnected)
                return; // Local mode: messages stay in local queue

            try
            {
                var fullMessage = $"{_localNodeId}|{message}";
                await _subscriber.PublishAsync(RedisChannel.Literal(MESSAGE_CHANNEL), fullMessage);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to broadcast message: {ex.Message}");
            }
        }

        /// <summary>
        /// Broadcast session join event to all nodes
        /// </summary>
        public async Task BroadcastSessionJoinAsync(SessionInfo sessionInfo)
        {
            if (sessionInfo == null)
                throw new ArgumentNullException(nameof(sessionInfo));

            if (!IsRedisConnected)
                return; // Local mode: only local sessions known

            try
            {
                var json = JsonSerializer.Serialize(sessionInfo);
                var fullMessage = $"{_localNodeId}|JOIN:{json}";
                await _subscriber.PublishAsync(RedisChannel.Literal(SESSION_CHANNEL), fullMessage);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to broadcast session join: {ex.Message}");
            }
        }

        /// <summary>
        /// Broadcast session leave event to all nodes
        /// </summary>
        public async Task BroadcastSessionLeaveAsync(Guid sessionId)
        {
            if (!IsRedisConnected)
                return; // Local mode: only local sessions known

            try
            {
                var fullMessage = $"{_localNodeId}|LEAVE:{sessionId}";
                await _subscriber.PublishAsync(RedisChannel.Literal(SESSION_CHANNEL), fullMessage);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to broadcast session leave: {ex.Message}");
            }
        }

        /// <summary>
        /// Get all sessions known to this node (local + remote)
        /// </summary>
        public IEnumerable<SessionInfo> GetRemoteSessions()
        {
            return _remoteSessionCache.Values.ToList();
        }

        /// <summary>
        /// Get a specific remote session by ID
        /// </summary>
        public SessionInfo GetRemoteSession(Guid sessionId)
        {
            _remoteSessionCache.TryGetValue(sessionId, out var sessionInfo);
            return sessionInfo;
        }

        /// <summary>
        /// Get count of remote sessions
        /// </summary>
        public int GetRemoteSessionCount() => _remoteSessionCache.Count;

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
