# Redis Broadcasting Code Structure

## Class Diagram

```
┌─────────────────────────────────────────────────────────┐
│                 MessageBroadcaster                      │
├─────────────────────────────────────────────────────────┤
│ - _redis: IConnectionMultiplexer                        │
│ - _subscriber: ISubscriber                              │
│ - _localNodeId: string (Guid)                           │
│ - _onMessageReceived: Func<string, Task>               │
│ - _redisAvailable: bool                                 │
├─────────────────────────────────────────────────────────┤
│ + IsRedisConnected: bool                                │
│ + InitializeAsync(redisConnectionString)               │
│ + OnMessageReceived(handler)                            │
│ + BroadcastAsync(message): Task                         │
│ + DisposeAsync(): ValueTask                             │
└─────────────────────────────────────────────────────────┘
         │
         │ uses
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│                   Terminal (abstract)                   │
├─────────────────────────────────────────────────────────┤
│ - messageBroadcaster: MessageBroadcaster                │
│ - messageQueue: ConcurrentQueue<string>                 │
├─────────────────────────────────────────────────────────┤
│ + SetMessageBroadcaster(broadcaster)                    │
│ + PageMessage(message)                                  │
│ + checkPage()                                           │
└─────────────────────────────────────────────────────────┘
         ▲                          ▲
         │                          │
         │ extends                  │ extends
         │                          │
    ┌────────────────┐         ┌──────────────────┐
    │ ConsoleTerminal│         │  TelnetTerminal  │
    └────────────────┘         └──────────────────┘


┌─────────────────────────────────────────────────────────┐
│                      Server                             │
├─────────────────────────────────────────────────────────┤
│ - messageBroadcaster: MessageBroadcaster                │
│ - configuration: IConfigurationRoot                     │
├─────────────────────────────────────────────────────────┤
│ + InitializeAsync(): Task                               │
│ + Dispose()                                             │
│ + RunConsoleSession()                                   │
│ - ListenerThread()                                      │
└─────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────┐
│               TelnetHostedService                       │
├─────────────────────────────────────────────────────────┤
│ + ExecuteAsync(CancellationToken)                       │
└─────────────────────────────────────────────────────────┘
         │
         │ creates & initializes
         │
         ▼
      Server
```

## Sequence Diagram: Message Broadcasting

```
Node 1: Terminal A        Node 1: Server         Redis         Node 2: Server        Node 2: Terminal B
    │                        │                    │                │                    │
    │ PageMessage("hi")       │                    │                │                    │
    ├──────────────────────>  │                    │                │                    │
    │                         │ BroadcastAsync()   │                │                    │
    │                         ├──────────────────> │                │                    │
    │                         │   Pub NodeID|"hi"  │                │                    │
    │                         │                    ├──────────────> │ OnMessageReceived()│
    │                         │                    │                ├──────────────────> │
    │                         │                    │                │   PageMessage()    │
    │                         │                    │                │                    │
    │ checkPage()             │                    │                │ checkPage()        │
    │ Show "hi" to Terminal A │                    │                │ Show "hi" to B     │
    │ <local queue>           │                    │                │ <from Redis>       │
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
                    │
                    └─> server.InitializeAsync()
                            │
                            └─> new MessageBroadcaster()
                            │
                            └─> broadcaster.InitializeAsync(
                                    configuration["Redis:ConnectionString"]
                                    OR env["REDIS_CONNECTION_STRING"]
                                    OR default "localhost:6379"
                                )
                                    │
                                    └─> ConnectionMultiplexer.ConnectAsync()
                                    │
                                    ├─ Success: _redisAvailable = true
                                    │           Subscribe to "sezam:broadcast"
                                    └─ Failure: _redisAvailable = false
                                                (graceful fallback)
                    │
                    └─> server.Start()
                            │
                            └─> ListenerThread()
                                    │
                                    └─> Accept connection
                                    │
                                    └─> new TelnetTerminal(tcpClient)
                                    │
                                    └─> terminal.SetMessageBroadcaster(broadcaster)
                                    │       └─> broadcaster.OnMessageReceived(callback)
                                    │
                                    └─> new Session(terminal)
```

## Call Stack: Message Broadcasting

```
User sends command "PAGE message"
    │
    └─> Session.InputAndExecCmd()
            │
            └─> CommandSet.ExecuteCommand()
                    │
                    └─> Page.Execute()
                            │
                            └─> terminal.PageMessage("message")
                                    │
                                    ├─> messageQueue.Enqueue("message")
                                    ├─> paged.TrySetResult()
                                    │
                                    └─> messageBroadcaster?.BroadcastAsync("message")
                                            │
                                            └─> subscriber.PublishAsync(
                                                    "sezam:broadcast",
                                                    "NodeID|message"
                                                )
                                                    │
                                                    └─ Other nodes receive via subscriber.OnMessage()
                                                            │
                                                            └─> OnMessageReceived callback
                                                                    │
                                                                    └─> PageMessage(msgFromRedis)
                                                                            │
                                                                            └─> messageQueue.Enqueue()
                                                                            └─> paged.TrySetResult()
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
├── Console/
│   ├── Messaging/
│   │   └── MessageBroadcaster.cs          ← NEW
│   ├── Terminal/
│   │   ├── Terminal.cs                    ← MODIFIED
│   │   ├── ConsoleTerminal.cs
│   │   └── TelnetTerminal.cs
│   ├── Server.cs                          ← MODIFIED
│   ├── Session.cs
│   └── Sezam.Console.csproj               ← MODIFIED
│
├── Telnet/
│   ├── TelnetHostedService.cs             ← MODIFIED
│   ├── TelnetServer.cs
│   ├── ConsoleLoop.cs
│   ├── appsettings.json                   ← MODIFIED
│   └── Sezam.Telnet.csproj
│
├── Web/
│   ├── Startup.cs                         ← MODIFIED
│   ├── Program.cs
│   ├── appsettings.json                   ← MODIFIED
│   └── Sezam.Web.csproj                   ← MODIFIED
│
├── Data/
│   └── ...
│
├── Commands/
│   └── ...
│
└── Doc/
    ├── REDIS_BROADCASTING.md              ← NEW
    ├── REDIS_DEPLOYMENT_EXAMPLES.md       ← NEW
    ├── REDIS_IMPLEMENTATION_SUMMARY.md    ← NEW
    ├── REDIS_QUICKSTART.md                ← NEW
    ├── REDIS_CODE_STRUCTURE.md            ← NEW (this file)
    └── ...
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
