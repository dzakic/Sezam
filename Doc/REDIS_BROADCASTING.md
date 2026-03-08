# Redis Message Broadcasting for Distributed Sezam

## Overview

The Sezam system now supports distributed message broadcasting across multiple nodes in a Kubernetes/Docker swarm deployment via Redis Pub/Sub. The system gracefully degrades to local-only mode when Redis is unavailable, making it suitable for both single-node development and multi-node production deployments.

## Architecture

### Components

1. **MessageBroadcaster** (`Console/Messaging/MessageBroadcaster.cs`)
   - Manages Redis connection and Pub/Sub lifecycle
   - Handles graceful fallback when Redis is unavailable
   - Provides async initialization with configurable connection timeouts
   - Unique node ID prevents duplicate message processing

2. **Terminal Integration** (`Console/Terminal/Terminal.cs`)
   - `SetMessageBroadcaster()`: Wires the broadcaster to a terminal instance
   - `PageMessage()`: Broadcasts messages to other nodes when available
   - Receives messages from other nodes via Redis callback

3. **Server Management** (`Console/Server.cs`)
   - Initializes broadcaster during startup with configuration
   - Injects broadcaster into terminal instances (Telnet and Console)
   - Disposes broadcaster cleanly on shutdown

## Message Flow

### Local Mode (No Redis)
```
User A Connected      User B Connected
Terminal 1 ---------> Terminal 2
  |                      |
  +---> PageMessage()    (local queue only)
  |     (local queue)    |
  +---> checkPage()      |
```

### Multi-Node Mode (With Redis)
```
Node 1 (Pod 1)                      Node 2 (Pod 2)
Terminal 1 ---> MessageBroadcaster ---> Redis Channel "sezam:broadcast"
   |                |                           |
   |                +---> BroadcastAsync() <----+--> MessageBroadcaster
   |                                             |         |
   +---> PageMessage()                           +---> OnMessageReceived()
         |                                              |
         +---> messageQueue                            +---> pageMessage()
               |                                              |
               +---> checkPage()                             +---> messageQueue
```

## Configuration

### Environment Variables

```bash
# Redis connection string (defaults to localhost:6379 if not set)
REDIS_CONNECTION_STRING=redis:6379

# Or use standard Redis URI format
REDIS_CONNECTION_STRING=redis://username:password@redis.example.com:6379
```

### appsettings.json

```json
{
  "Redis": {
    "ConnectionString": "localhost:6379"
  }
}
```

### Precedence Order (highest to lowest)
1. Environment variable: `REDIS_CONNECTION_STRING`
2. Configuration: `Redis:ConnectionString` in appsettings.json
3. Default: `localhost:6379`

## Graceful Degradation

The system handles Redis unavailability transparently:

1. **Connection Attempt**
   - Timeout: 2 seconds
   - AbortOnConnectFail: False (allows fallback)
   - SyncTimeout: 2 seconds

2. **Failure Handling**
   - Redis unavailable → `_redisAvailable = false`
   - Messages stay in local `messageQueue` only
   - No errors thrown to user
   - System continues operating normally

3. **Runtime Status Check**
   ```csharp
   if (messageBroadcaster.IsRedisConnected)
   {
       // Multi-node broadcast available
   }
   else
   {
       // Local-only mode
   }
   ```

## Message Format

Messages broadcast via Redis include the sending node's ID to prevent echo-back:

```
<NodeID>|<message_content>
```

Example:
```
a1b2c3d4-e5f6-47a8-9b0c-1d2e3f4a5b6c|SYSTEM: Users online count changed
```

## Integration Points

### Telnet Server (`Telnet/TelnetHostedService.cs`)
```csharp
server = new Server(configuration);
await server.InitializeAsync();  // Initialize Redis broadcaster
server.Start();
```

### Console Session
```csharp
var console = new ConsoleTerminal();
if (messageBroadcaster != null)
    console.SetMessageBroadcaster(messageBroadcaster);
```

### Web Project (`Web/Startup.cs`)
```csharp
services.AddSingleton<MessageBroadcaster>(sp =>
{
    var broadcaster = new MessageBroadcaster();
    var redisConnectionString = Configuration?["Redis:ConnectionString"] 
        ?? Environment.GetEnvironmentVariable("REDIS_CONNECTION_STRING")
        ?? "localhost:6379";
    broadcaster.InitializeAsync(redisConnectionString).GetAwaiter().GetResult();
    return broadcaster;
});
```

## Deployment Considerations

### Docker Compose / Kubernetes
Ensure Redis service is available:

```yaml
# In docker-compose.yml or deployment.yaml
redis:
  image: redis:7-alpine
  ports:
    - "6379:6379"
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 5s
    timeout: 3s
    retries: 5
```

### Network Configuration
- Redis typically runs on port 6379
- In Kubernetes, use DNS name: `redis:6379` or `redis.sezam.svc.cluster.local:6379`
- In Docker Compose, use service name: `redis:6379`

### Resource Limits
- Connection pool is minimal (one connection for pub/sub)
- Memory usage: ~10-50KB per active subscription
- Network traffic: Only when page messages are broadcasted

## Debugging

### Check Redis Connection
```csharp
if (messageBroadcaster.IsRedisConnected)
{
    Debug.WriteLine("Redis connected - multi-node broadcast active");
}
else
{
    Debug.WriteLine("Redis unavailable - local-only mode");
}
```

### Enable Tracing
The system logs connection errors to the debug output:
```
Redis connection failed: Connection refused
```

### Testing Locally
Without Redis:
```bash
dotnet run  # Works fine, messages stay local
```

With Redis (Docker):
```bash
docker run -d -p 6379:6379 redis:7-alpine
dotnet run  # Messages broadcast to other nodes
```

## Future Enhancements

1. **Metrics**: Track broadcast message count and latency
2. **Resilience**: Implement Redis reconnection with exponential backoff
3. **Message Filtering**: Allow per-node message filtering for optimization
4. **Message Persistence**: Redis streams for message history/recovery
5. **Status API**: Expose Redis connection status via REST endpoint

## References

- StackExchange.Redis Documentation: https://stackexchange.github.io/StackExchange.Redis/
- Sezam Architecture: [../Doc/IMPLEMENTATION_CHECKLIST.md](../Doc/IMPLEMENTATION_CHECKLIST.md)
