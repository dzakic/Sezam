# Redis Broadcasting Code Structure

## Class Diagram

```
┌─────────────────────────────────────────────────────────┐
│                 MessageBroadcaster                      │
├─────────────────────────────────────────────────────────┤
│ - _redis: IConnectionMultiplexer                        │
│ - _subscriber: ISubscriber                              │
│ - _localNodeId: string (Guid)                           │
│ - _redisAvailable: bool                                 │
│ - _logger: ILogger                                      │
│ - _remoteSessionCache: ConcurrentDictionary<Guid, SI>   │
├─────────────────────────────────────────────────────────┤
│ + IsRedisConnected: bool                                │
│ + LocalNodeId: string                                   │
│ + InitializeAsync(connectionString)                     │
│ + BroadcastAsync(message): Task                         │
│ + BroadcastSessionUpdateAsync(SessionInfo): Task        │
│ + BroadcastSessionLeaveAsync(Guid): Task                │
│ + GetRemoteSessions(): IEnumerable<SessionInfo>         │
│ + GetRemoteSession(Guid): SessionInfo                   │
│ + GetRemoteSessionCount(): int                          │
│ + DisposeAsync(): ValueTask                             │
│ - HandleSessionEvent(message)                           │
│ - HandleMessageEnvelope(envelope)                       │
│ - HandleUpdate/Leave/DiscoverRequest/DiscoverResponse   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                      Data.Store                         │
├─────────────────────────────────────────────────────────┤
│ + Sessions: ConcurrentDictionary<Guid, ISession>        │
│ + MessageBroadcaster: MessageBroadcaster                │
├─────────────────────────────────────────────────────────┤
│ + LocalBroadcast(from, message)                         │
│ + GlobalBroadcast(from, message)                        │
│ + SendToUser(toUser, from, message)                     │
│ + SendToChat(room, from, message)                       │
│ + AddSession(ISession) / RemoveSession(ISession)        │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              DistributedSessionRegistry                 │
├─────────────────────────────────────────────────────────┤
│ - _broadcaster: MessageBroadcaster                      │
├─────────────────────────────────────────────────────────┤
│ + GetAllSessions(): IEnumerable<SessionInfo>            │
│ + GetLocalSessions(): IEnumerable<SessionInfo>          │
│ + GetRemoteSessions(): IEnumerable<SessionInfo>         │
│ + IsUserOnline(username): bool                          │
│ + GetSessionByUsername(username): SessionInfo            │
│ + GetOnlineUsernames(): IEnumerable<string>             │
│ + GetNodeSummaries(): IEnumerable<NodeSummary>          │
└─────────────────────────────────────────────────────────┘
```

## Sequence Diagram: Page Message (User → User)

```
Node 1: Session A          Data.Store          Redis            Node 2: Broadcaster      Node 2: Session B
    │                         │                  │                    │                       │
    │ Page "bob hello"        │                  │                    │                       │
    ├──────────────────────>  │                  │                    │                       │
    │  SendToUser("bob",      │                  │                    │                       │
    │    "alice", "hello")    │                  │                    │                       │
    │                         │ bob local?       │                    │                       │
    │                         │ No → Redis       │                    │                       │
    │                         ├────────────────> │                    │                       │
    │                         │ USER:bob:alice:  │                    │                       │
    │                         │ hello            │                    │                       │
    │                         │                  ├──────────────────> │                       │
    │                         │                  │ HandleEnvelope     │                       │
    │                         │                  │                    │ find "bob" locally     │
    │                         │                  │                    ├─────────────────────> │
    │                         │                  │                    │ Deliver("alice",      │
    │                         │                  │                    │   "hello")             │
    │                         │                  │                    │                       │ → terminal
```

## Sequence Diagram: Node Discovery

```
Node B (new)              Redis              Node A (existing)
    │                       │                      │
    │ InitializeAsync()     │                      │
    │ Subscribe             │                      │
    │ DISCOVER ───────────> │ ───────────────────> │
    │                       │                      │ HandleDiscoverRequest()
    │                       │                      │ collect local sessions
    │                       │ <─────────────────── │ DISCOVER_RESPONSE:[...]
    │ <──────────────────── │                      │
    │ HandleDiscoverResponse│                      │
    │ upsert remote cache   │                      │
    │                       │                      │
```

## Call Stack: Initialization

```
Program.Main()
    │
    └─> Host.CreateApplicationBuilder()
            │
            └─> TelnetHostedService.ExecuteAsync()
                    │
                    └─> new Server(configuration)
                    │       └─> Store.ConfigureFrom(configuration)
                    │
                    └─> server.InitializeAsync()
                            │
                            └─> if RedisEnabled:
                                    │
                                    └─> new MessageBroadcaster()
                                    │       → Store.MessageBroadcaster = broadcaster
                                    │
                                    └─> broadcaster.InitializeAsync(RedisConnectionString)
                                            │
                                            └─> ConnectionMultiplexer.ConnectAsync()
                                            │
                                            ├─ Success: _redisAvailable = true
                                            │   Subscribe to "sezam:broadcast"
                                            │   Subscribe to "sezam:sessions"
                                            │   Publish DISCOVER request
                                            │
                                            └─ Failure: _redisAvailable = false
                                                        (local-only mode)
                    │
                    └─> server.Start()
                            │
                            └─> ListenerThread()
                                    └─> Accept connection
                                    └─> new TelnetTerminal(tcpClient)
                                    └─> new Session(terminal)
                                    └─> Store.AddSession(session)
```

## Call Stack: Page Message

```
User sends command "PAGE alice hello"
    │
    └─> Session.InputAndExecCmd()
            │
            └─> Root.Page()
                    │
                    └─> FindOnlineUser("alice")  → SessionInfo
                    │       (searches local + remote via registry)
                    │
                    └─> Store.SendToUser("alice", "bob", "hello")
                            │
                            ├─ alice is local?
                            │   YES → alice.Deliver("bob", "hello")
                            │           → terminal.PageMessage(...)
                            │
                            └─ alice is remote?
                                → BroadcastAsync("USER:alice:bob:hello")
                                    → Redis "sezam:broadcast" channel
                                        → Remote node: HandleMessageEnvelope()
                                            → find local "alice"
                                            → alice.Deliver("bob", "hello")
```

## Call Stack: Chat Message

```
User types "hello" in Chat mode
    │
    └─> Chat.ExecuteCommand("hello")
            │
            └─> Chat.Say(room="*", "hello")
                    │
                    └─> Store.SendToChat("*", "bob", "hello")
                            │
                            ├─ All local sessions: Deliver("bob", ":chat:*:hello")
                            │
                            └─ Redis: BroadcastAsync("CHAT:*:bob:hello")
                                → Remote nodes: deliver to all their locals
```

## Configuration Resolution

```
Redis Connection String Resolution Priority:
(Highest)
    ↓
1. Environment Variable: REDIS_CONNECTION_STRING
    ↓
2. appsettings.json: Redis.ConnectionString
    ↓
3. Default: "localhost:6379"
(Lowest)

Example Resolution:
    getConnectionString()
        ├─ Environment.GetEnvironmentVariable("REDIS_CONNECTION_STRING")
        │   ├─ Found: "redis.prod.azure.com:6379" → use it
        │   └─ Not found: continue
        ├─ Configuration["Redis:ConnectionString"]
        │   ├─ Found: "localhost:6379" → use it
        │   └─ Not found: continue
        └─ Default: "localhost:6379"
```

## File Organization

```
Sezam/
├── Data/
│   ├── Store.cs                            ← Messaging API: SendToUser, SendToChat, etc.
│   ├── Sessions.cs                         ← ISession interface
│   └── Messaging/
│       ├── MessageBroadcaster.cs           ← Redis Pub/Sub, protocol handling
│       ├── SessionInfo.cs                  ← Universal session descriptor
│       └── DistributedSessionRegistry.cs   ← Unified session query layer
│
├── Console/
│   ├── Session.cs                          ← PublishSessionUpdate(), Deliver()
│   ├── Server.cs                           ← Initialization, lifecycle
│   ├── Commands/
│   │   └── CommandSet.cs                   ← FindOnlineUser(), GetAllSessions()
│   └── Terminal/
│       ├── Terminal.cs
│       ├── ConsoleTerminal.cs
│       └── TelnetTerminal.cs
│
├── Commands/
│   ├── Root.cs                             ← Page, Who commands
│   └── Chat/
│       └── Chat.cs                         ← Chat To, Say commands
│
├── Telnet/
│   ├── TelnetHostedService.cs
│   └── ConsoleLoop.cs
│
└── Web/
    └── Startup.cs
```

## Class Dependency Graph

```
MessageBroadcaster
    ├── uses: StackExchange.Redis (IConnectionMultiplexer)
    ├── uses: System.Threading.Tasks
    └── uses: System

Terminal (abstract)
    ├── uses: MessageBroadcaster
    ├── uses: System.Collections.Concurrent
    └── uses: System.Threading.Tasks

ConsoleTerminal : Terminal
    └── uses: System.Console

TelnetTerminal : Terminal
    ├── uses: System.Net.Sockets
    └── uses: System.Text

Server
    ├── uses: MessageBroadcaster
    ├── uses: Terminal (creates instances)
    ├── uses: Session
    ├── uses: Microsoft.Extensions.Configuration
    └── uses: System.Net.Sockets

TelnetHostedService : BackgroundService
    ├── uses: Server
    ├── uses: MessageBroadcaster (indirectly via Server)
    ├── uses: Microsoft.Extensions.Hosting
    └── uses: Microsoft.Extensions.Configuration

Startup (Web)
    ├── creates: MessageBroadcaster (as singleton)
    ├── uses: Microsoft.Extensions.DependencyInjection
    └── uses: Microsoft.Extensions.Configuration
```

## State Machine: Broadcaster Lifecycle

```
┌─────────────────────┐
│   UNINITIALIZED     │
│  messageBroadcaster │
│      = null         │
└──────────┬──────────┘
           │ new MessageBroadcaster()
           ▼
┌─────────────────────────────────────────────────────────┐
│           INITIALIZING (InitializeAsync)                │
│  - Attempt connection to Redis                          │
│  - 2s timeout, no-fail-on-error                         │
└──────────┬──────────────────────────────────────────────┘
           │
           ├─ Connection Success
           │   └─ _redisAvailable = true
           │   └─ Subscribe to "sezam:broadcast"
           ▼
    ┌──────────────────┐
    │   CONNECTED      │
    │ _redisAvailable  │
    │     = true       │
    │  Broadcasts work │
    └──────────────────┘
           │
           ├─ DisposeAsync()
           │
           ▼
    ┌──────────────────┐
    │   DISPOSED       │
    │ _redis.Dispose() │
    └──────────────────┘
           
           ├─ Connection Failure
           │   └─ _redisAvailable = false
           │   └─ Catch exception (debug output)
           ▼
    ┌──────────────────────────────────────┐
    │   LOCAL_MODE (Fallback)              │
    │  _redisAvailable = false              │
    │  - Messages stay local only           │
    │  - No errors thrown                   │
    │  - System operates normally           │
    └──────────────────────────────────────┘
           │
           └─ DisposeAsync() (no-op)
```

## Message Format in Transit

```
Redis Pub/Sub Channel: "sezam:broadcast"

Message Format: "<NodeID>|<content>"

Example Messages:
    │
    ├─ a1b2c3d4-e5f6-47a8-9b0c-1d2e3f4a5b6c|Server shutting down
    │
    ├─ f1e2d3c4-b5a6-9870-1234-567890abcdef|User joined: Alice
    │
    └─ a1b2c3d4-e5f6-47a8-9b0c-1d2e3f4a5b6c|Message from broadcast

Processing:
    1. Redis sends message to all subscribers
    2. Each subscriber receives via OnMessage callback
    3. Extract NodeID and content
    4. Filter: if message.NodeID == LocalNodeID → ignore (echo-back prevention)
    5. Else: add to local messageQueue
    6. checkPage() displays to terminal
```

## Error Handling Flow

```
InitializeAsync()
    │
    ├─ Fails to connect
    │   │
    │   └─ Exception caught
    │       │
    │       ├─ Debug.WriteLine("Redis connection failed: {ex.Message}")
    │       │
    │       └─ _redisAvailable = false
    │           │
    │           └─ System continues normally
    │
    ├─ Connected but then disconnected
    │   └─ IsRedisConnected returns false
    │       └─ BroadcastAsync() silently returns
    │
    └─ Message broadcast fails
        └─ Catch exception in BroadcastAsync()
            └─ Debug.WriteLine("Failed to broadcast message: {ex.Message}")
                └─ System continues
```

---

This structure provides a clean separation of concerns with Redis concerns isolated in `MessageBroadcaster` and integrated transparently into the existing `Terminal` and `Server` classes.
