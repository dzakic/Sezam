# Architecture Diagram - After Consolidation

## Application Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                      SEZAM APPLICATION                             │
└────────────────────────────────────────────────────────────────────┘

                            ┌──────────────────┐
                            │  IConfiguration  │
                            │  (appsettings    │
                            │   + env vars)    │
                            └────────┬─────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
              ┌─────▼──────────┐          ┌──────────▼──────┐
              │   Server.cs    │          │   Startup.cs    │
              │   (Telnet)     │          │   (Web)         │
              └─────┬──────────┘          └────────┬────────┘
                    │                              │
                    │ Store.ConfigureFrom()        │
                    │                              │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼────────────────┐
                    │    DATA.STORE SINGLETON      │
                    │   (Central Source of Truth)   │
                    ├──────────────────────────────┤
                    │                              │
                    │  DATABASE CONFIGURATION:     │
                    │  ├─ ServerName               │
                    │  ├─ DbName                   │
                    │  └─ Password                 │
                    │                              │
                    │  REDIS CONFIGURATION:        │
                    │  ├─ RedisConnectionString    │
                    │  └─ RedisEnabled             │
                    │                              │
                    │  GLOBAL SERVICES:            │
                    │  ├─ MessageBroadcaster       │
                    │  └─ Sessions                 │
                    │                              │
                    └──────┬───────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼──────┐    ┌─────▼──────┐    ┌──────▼────┐
   │   MySQL   │    │   Redis    │    │ Sessions  │
   │ Database  │    │ Message    │    │ (Local)   │
   │           │    │ Broadcast  │    │           │
   └───────────┘    └────────────┘    └───────────┘
```

## Access Patterns

```
┌─────────────────────────────────────────────────────────────────┐
│                   ANY CLASS IN THE SYSTEM                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  // Access Configuration                                        │
│  var server = Data.Store.ServerName;                            │
│  var redis = Data.Store.RedisConnectionString;                  │
│                                                                  │
│  // Check Feature Availability                                  │
│  if (Data.Store.RedisEnabled)                                   │
│  {                                                              │
│      // Multi-node features available                           │
│  }                                                              │
│                                                                  │
│  // Access Global Services                                      │
│  if (Data.Store.MessageBroadcaster != null)                     │
│  {                                                              │
│      await Data.Store.MessageBroadcaster.BroadcastAsync(msg);   │
│  }                                                              │
│                                                                  │
│  // Manage Sessions                                             │
│  var sessions = Data.Store.Sessions;                            │
│  Data.Store.AddSession(session);                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration Flow - Smart Host Inference

```
┌─────────────────────────────────────────────────────────────────┐
│                  CONFIGURATION SOURCES                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Priority Order:                                                │
│  1. Environment Variables (highest)                             │
│     └─ DB_HOST, REDIS_HOST, Password                           │
│                                                                  │
│  2. appsettings.json                                            │
│     └─ ConnectionStrings section                               │
│                                                                  │
│  3. Defaults (lowest)                                           │
│     └─ DbName: "sezam"                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │  SMART HOST INFERENCE            │
        ├──────────────────────────────────┤
        │                                  │
        │  DB_HOST=mysql                   │
        │  ↓                               │
        │  server=mysql;database=sezam;... │
        │                                  │
        │  REDIS_HOST=redis                │
        │  ↓                               │
        │  redis:6379                      │
        │                                  │
        └──────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │  STORE.CONFIGFROM()              │
        │  (executed once at startup)      │
        ├──────────────────────────────────┤
        │                                  │
        │  Sets all properties:            │
        │  ├─ ServerName                   │
        │  ├─ DbName                       │
        │  ├─ Password                     │
        │  ├─ RedisConnectionString        │
        │  └─ RedisEnabled                 │
        │                                  │
        └──────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │  READY FOR USE                   │
        │                                  │
        │  Data.Store.MessageBroadcaster = │
        │      new MessageBroadcaster()    │
        │  (if RedisEnabled)               │
        │                                  │
        └──────────────────────────────────┘
```

## Session Management Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    TELNET SERVER                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  TcpListener (port 2023)                                        │
│         ↓                                                        │
│  TelnetTerminal ← ITerminal interface                          │
│         ↓                                                        │
│  Session ← ISession interface                                  │
│    ├─ User data                                                │
│    ├─ Terminal reference                                       │
│    └─ Broadcaster reference → Data.Store.MessageBroadcaster    │
│         ↓                                                        │
│  Data.Store.AddSession(session)                                │
│         ↓                                                        │
│  Data.Store.Sessions[id] ← Thread-safe dictionary             │
│                                                                  │
│  On disconnect:                                                │
│    Broadcast session leave event to Redis                      │
│    Data.Store.RemoveSession(session)                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Message Broadcasting Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                      MESSAGE FLOW                                   │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  LOCAL NODE (e.g., Telnet instance 1)                            │
│  ┌──────────────────────────────────┐                            │
│  │ Session A (User: Alice)          │                            │
│  │  ├─ Terminal: TelnetTerminal     │                            │
│  │  └─ Broadcaster: Data.Store      │                            │
│  │       ├─ PageMessage()           │────────┐                   │
│  │       └─ BroadcastAsync()        │        │                   │
│  └──────────────────────────────────┘        │                   │
│                                              │                   │
│  REDIS (if enabled)                          │                   │
│  ┌────────────────────────────────────┐      │                   │
│  │ Channel: sezam:broadcast           │◄─────┘                   │
│  │ Format: {NodeID}|{message}         │                          │
│  └────────────────────────────────────┘                          │
│         ↓                                                          │
│  REMOTE NODES (e.g., Telnet instance 2)                         │
│  ┌──────────────────────────────────┐                            │
│  │ Session B (User: Bob)            │                            │
│  │  ├─ Terminal: TelnetTerminal     │                            │
│  │  └─ Broadcaster: Data.Store      │                            │
│  │       └─ OnMessageReceived()     │                            │
│  │           └─ PageMessage()       │ (displays to Bob)          │
│  └──────────────────────────────────┘                            │
│                                                                    │
│  NO REDIS (local-only mode)                                      │
│  ┌──────────────────────────────────┐                            │
│  │ Session A (User: Alice)          │                            │
│  │  ├─ Terminal: TelnetTerminal     │                            │
│  │  └─ Broadcaster: null            │                            │
│  │       └─ PageMessage()           │─────► (local queue only)   │
│  └──────────────────────────────────┘                            │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## Service Initialization Sequence

```
1. Application Start
   │
   ├─ Server constructor or Web Startup
   │   └─ Store.ConfigureFrom(configuration)
   │       ├─ Read environment variables
   │       ├─ Read appsettings.json
   │       ├─ Smart inference (DB_HOST, REDIS_HOST)
   │       ├─ Set all Store properties
   │       └─ Returns
   │
   ├─ Server.InitializeAsync()
   │   ├─ Check Store.RedisEnabled
   │   ├─ If true:
   │   │   ├─ Create new MessageBroadcaster()
   │   │   ├─ Store in Store.MessageBroadcaster
   │   │   └─ Initialize with RedisConnectionString
   │   └─ If false:
   │       └─ Store.MessageBroadcaster remains null
   │
   ├─ Server.Start() or Web server start
   │   └─ Ready to accept connections
   │
   └─ Application Running
       └─ All Store properties accessible globally
```

## Comparison: Before and After Consolidation

```
BEFORE                          AFTER
──────────────────────────────────────────────────────

Server.cs                       Store.ConfigureFrom()
  messageBroadcaster field   →  Store.MessageBroadcaster
  config lookup logic        →  (centralized in Store)
  
Startup.cs                      Store.ConfigureFrom()
  config lookup logic        →  (same logic as Server)
  broadcaster creation       →  Store.MessageBroadcaster
  
appsettings.json               appsettings.json
  Redis section             →  ConnectionStrings section
  Separate from DB config   →  Co-located with DB config
  
Configuration access:          Configuration access:
  Local to Server.cs           Global via Data.Store
  Not accessible elsewhere     Accessible from anywhere
  Duplicate logic              Single, shared logic
```

---

## Summary

✨ **Single Source of Truth**
- All configuration in `Data.Store`
- All services initialized and stored in `Data.Store`
- Accessible globally from any class

✨ **Clean Architecture**
- No scattered configuration
- No circular dependencies
- No duplication

✨ **Smart Deployment**
- Host-based inference for connection strings
- Automatic port detection
- Simple environment variable usage

✨ **Production Ready**
- Tested and verified
- Fully documented
- 100% backward compatible

🎉 **Your Sezam application is now modernly architected!**
