# Distributed Sessions & Messaging

## Overview

Sezam automatically discovers and shares connected user sessions across all nodes in a swarm deployment. When a user connects to any node, that session information is broadcast to all other nodes via Redis, enabling every connection to see who else is online — even on different pods/containers.

Messages (Page, Chat) are routed through `Data.Store` with a local shortcut: if the target user is on the same node, delivery is instant without Redis. Otherwise the message is published via Redis for the remote node to deliver.

## Architecture

### Components

1. **SessionInfo** (`Data/Messaging/SessionInfo.cs`)
   - Universal session descriptor — used for local display, remote transport, and registry queries
   - JSON-serializable for Redis distribution between nodes
   - Contains: `Id`, `Username`, `ConnectTime`, `LoginTime`, `NodeId`, `TerminalId`, `State`, `IsLocal`, `ConnectedDuration`
   - `State` tracks current user activity (e.g. `"CHAT"`, `"TRANSFER"`, `"READ"`) — nullable, null means idle
   - `IsLocal` is not serialized — computed locally on each node

2. **ISession** (`Data/Sessions.cs`)
   - Minimal interface for live local sessions: `Id`, `Username`, `ConnectTime`, `LoginTime`, `Close()`, `Deliver()`
   - `Deliver(from, message)` pushes a message to the session's terminal
   - Only meaningful for local sessions (you can't `Deliver` to a remote session directly)

3. **MessageBroadcaster** (`Data/Messaging/MessageBroadcaster.cs`)
   - Redis Pub/Sub for session events and message routing
   - Session protocol on `sezam:sessions` channel: `UPDATE`, `LEAVE`, `DISCOVER`, `DISCOVER_RESPONSE`
   - Message protocol on `sezam:broadcast` channel: `BROADCAST`, `USER`, `CHAT`
   - Falls back to local-only mode if Redis is unavailable

4. **DistributedSessionRegistry** (`Data/Messaging/DistributedSessionRegistry.cs`)
   - Unified view of sessions across all nodes
   - All methods return `SessionInfo` (no separate `SessionDetails` type)
   - Query by username, session ID, node ID; get online usernames, node summaries

5. **Data.Store Messaging API** (`Data/Store.cs`)
   - `LocalBroadcast(from, message)` — this node only (e.g. "shutting down")
   - `GlobalBroadcast(from, message)` — all nodes (local + Redis)
   - `SendToUser(toUser, from, message)` — local shortcut, then Redis fallback
   - `SendToChat(room, from, message)` — all nodes, room `"*"` = public chat

### Type Hierarchy (Simplified)

```
ISession (interface)           SessionInfo (class)
├── Id                         ├── Id
├── Username                   ├── Username
├── ConnectTime                ├── ConnectTime
├── LoginTime                  ├── LoginTime
├── Close()                    ├── NodeId
└── Deliver(from, message)     ├── TerminalId
                               ├── State         (nullable: "CHAT", "READ", etc.)
                               ├── IsLocal        (not serialized)
                               └── ConnectedDuration (computed)

ISession = live local session (has terminal, can deliver messages)
SessionInfo = universal read-only view (local or remote, serializable)
```

## Message Flow

### Session Update (Login, State Change)

```
User Login / State Change
   ↓
Session.PublishSessionUpdate()
   ↓
SessionInfo.FromSession(this, nodeId, terminalId)
   ↓
BroadcastSessionUpdateAsync(sessionInfo)
   ↓
Redis Channel "sezam:sessions"
   {nodeId}|UPDATE:{SessionInfo JSON}
   ↓
Remote nodes: upsert in _remoteSessionCache
```

### Session Leave (Disconnect)

```
Session.Run() finally block
   ↓
BroadcastSessionLeaveAsync(Id)
   ↓
Redis Channel "sezam:sessions"
   {nodeId}|LEAVE:{sessionGuid}
   ↓
Remote nodes: remove from _remoteSessionCache
```

### Node Discovery (New Node Comes Online)

```
Node B starts → InitializeAsync()
   ↓
Publishes DISCOVER on sezam:sessions
   ↓
Node A receives DISCOVER
   → Collects Store.Sessions (locals)
   → Publishes DISCOVER_RESPONSE:[SessionInfo array]
   ↓
Node B receives DISCOVER_RESPONSE
   → Upserts each into _remoteSessionCache
```

### Page Message (User → User)

```
Page "alice hello"
   ↓
Store.SendToUser("alice", "bob", "hello")
   ↓
Is alice local? ──yes──→ alice.Deliver("bob", "hello") → terminal
   │
   no
   ↓
Redis: BROADCAST channel: "USER:alice:bob:hello"
   ↓
Remote node receives → HandleMessageEnvelope
   → finds local session "alice" → alice.Deliver("bob", "hello")
```

### Chat Message (Room Broadcast)

```
Chat "hi everyone"
   ↓
Store.SendToChat("*", "bob", "hi everyone")
   ↓
All local sessions: Deliver("bob", ":chat:*:hi everyone")
   ↓
Redis: BROADCAST channel: "CHAT:*:bob:hi everyone"
   ↓
Remote nodes: deliver to all their local sessions
```

## Usage Examples

### Session Queries

```csharp
// Create registry from the global broadcaster
var registry = new DistributedSessionRegistry(Data.Store.MessageBroadcaster);

// Get all online usernames (local + remote)
var onlineUsers = registry.GetOnlineUsernames();
// Result: ["Alice", "Bob", "Charlie"]

// Check if user is online (any node)
bool isOnline = registry.IsUserOnline("Alice");

// Get specific user's session info
SessionInfo session = registry.GetSessionByUsername("Alice");
// session.IsLocal, session.NodeId, session.ConnectedDuration, session.State
```

### Sending Messages

```csharp
// Page a specific user (local shortcut or Redis)
Data.Store.SendToUser("alice", "bob", "hey!");

// Chat to a room (all nodes)
Data.Store.SendToChat("*", "bob", "hello everyone");

// Local-only broadcast (e.g. shutdown notice)
Data.Store.LocalBroadcast("SYSTEM", "Server shutting down in 5 minutes");

// Global broadcast (all nodes)
Data.Store.GlobalBroadcast("ADMIN", "System maintenance at 22:00");
```

### In Commands

```csharp
// In CommandSet subclasses:

// Find an online user by partial name (local + remote)
var target = FindOnlineUser("ali");  // returns SessionInfo or null

// Get all sessions for display
var allSessions = GetAllSessions();  // returns IEnumerable<SessionInfo>
```

## Data Structures

### SessionInfo (JSON format on Redis)

```json
{
  "id": "a1b2c3d4-e5f6-47a8-9b0c-1d2e3f4a5b6c",
  "username": "alice",
  "connectTime": "2024-01-15T10:30:45Z",
  "loginTime": "2024-01-15T10:31:00Z",
  "nodeId": "xyz789ab-c123-...",
  "terminalId": "telnet-001",
  "state": "CHAT"
}
```

Note: `isLocal` and `connectedDuration` are not serialized — computed locally on each node.

### NodeSummary

```csharp
public class NodeSummary
{
    public string NodeId { get; set; }
    public bool IsLocal { get; set; }
    public int SessionCount { get; set; }
}
```

## Redis Channels & Protocol

### Session Channel: `sezam:sessions`

Format: `{nodeId}|{EventType}:{Data}`

| Event | Data | Receiver Action |
|---|---|---|
| `UPDATE` | Full SessionInfo JSON | Upsert in remote cache |
| `LEAVE` | Session GUID | Remove from remote cache |
| `DISCOVER` | *(empty)* | Respond with all local sessions |
| `DISCOVER_RESPONSE` | SessionInfo[] JSON array | Upsert each in remote cache |

### Message Channel: `sezam:broadcast`

Format: `{nodeId}|{EnvelopeType}:{payload}`

| Envelope | Payload | Receiver Action |
|---|---|---|
| `BROADCAST` | `{from}:{message}` | Deliver to all local sessions |
| `USER` | `{toUser}:{from}:{message}` | Find local session by username, deliver |
| `CHAT` | `{room}:{from}:{message}` | Deliver to all local sessions |

## Local vs. Remote

| | Local Session | Remote Session |
|---|---|---|
| **Type** | `ISession` (live object in `Store.Sessions`) | `SessionInfo` (cached from Redis) |
| **Can deliver** | Yes — `session.Deliver(from, msg)` | No — must route via `Store.SendToUser()` |
| **Can close** | Yes — `session.Close()` | No |
| **Terminal access** | Yes | No |
| **Updated by** | Direct property changes + `PublishSessionUpdate()` | Redis UPDATE events |

## Error Handling

- Redis unavailable at startup → local-only mode, no errors
- Redis disconnects mid-session → messages to remote users silently fail (logged as warning)
- Broadcast failures → logged but session continues normally
- Malformed Redis events → logged and skipped

## File References

- **SessionInfo**: `Data/Messaging/SessionInfo.cs`
- **ISession**: `Data/Sessions.cs`
- **MessageBroadcaster**: `Data/Messaging/MessageBroadcaster.cs`
- **DistributedSessionRegistry**: `Data/Messaging/DistributedSessionRegistry.cs`
- **Store messaging API**: `Data/Store.cs`
- **Session integration**: `Console/Session.cs`
- **Command helpers**: `Console/Commands/CommandSet.cs` (`FindOnlineUser`, `GetAllSessions`)
