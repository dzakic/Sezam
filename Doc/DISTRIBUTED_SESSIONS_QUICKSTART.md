# Distributed Sessions & Messaging — Quick Reference

## Session Lookup

```csharp
var registry = new DistributedSessionRegistry(Data.Store.MessageBroadcaster);

// Who's online (all nodes)
var onlineUsers = registry.GetOnlineUsernames();

// Is user online?
if (registry.IsUserOnline("Alice")) { ... }

// Get session details
SessionInfo session = registry.GetSessionByUsername("Alice");
// session.IsLocal, session.NodeId, session.State, session.ConnectedDuration
```

## Sending Messages

```csharp
// Page a user (local shortcut → Redis fallback)
Data.Store.SendToUser("alice", "bob", "hey!");

// Chat to a room (all nodes; "*" = public chat)
Data.Store.SendToChat("*", "bob", "hello everyone");

// Local-only broadcast (shutdown notice)
Data.Store.LocalBroadcast("SYSTEM", "Server shutting down");

// Global broadcast (all nodes)
Data.Store.GlobalBroadcast("ADMIN", "Maintenance at 22:00");
```

## In Commands (CommandSet subclasses)

```csharp
// Find user by partial name (local + remote)
var target = FindOnlineUser("ali");  // → SessionInfo or null

// Get all sessions for display
foreach (var s in GetAllSessions())
    await session.terminal.Line($"{s.Username} {(s.IsLocal ? "" : "@remote")}");
```

## Session Updates (from Session.cs)

```csharp
// After any session detail change (login, state change):
await PublishSessionUpdate();  // sends full snapshot to all nodes
```

## Registry Methods

| Method | Returns | Description |
|---|---|---|
| `GetAllSessions()` | `IEnumerable<SessionInfo>` | Local + remote |
| `GetLocalSessions()` | `IEnumerable<SessionInfo>` | This node only |
| `GetRemoteSessions()` | `IEnumerable<SessionInfo>` | Other nodes only |
| `IsUserOnline(name)` | `bool` | Any node |
| `GetSessionByUsername(name)` | `SessionInfo` | First match |
| `GetSessionById(guid)` | `SessionInfo` | By session ID |
| `GetOnlineUsernames()` | `IEnumerable<string>` | Sorted, distinct |
| `GetLocalSessionCount()` | `int` | |
| `GetRemoteSessionCount()` | `int` | |
| `GetTotalSessionCount()` | `int` | |
| `GetSessionsByNode(nodeId)` | `IEnumerable<SessionInfo>` | |
| `GetNodeSummaries()` | `IEnumerable<NodeSummary>` | |

## Store Messaging API

| Method | Scope | Use Case |
|---|---|---|
| `LocalBroadcast(from, msg)` | This node | Shutdown notice |
| `GlobalBroadcast(from, msg)` | All nodes | System announcement |
| `SendToUser(to, from, msg)` | Local shortcut → Redis | Page, DM |
| `SendToChat(room, from, msg)` | All nodes | Chat rooms |

## Redis Protocol Summary

### `sezam:sessions` channel

| Event | Data | Action |
|---|---|---|
| `UPDATE` | SessionInfo JSON | Upsert remote cache |
| `LEAVE` | Session GUID | Remove from cache |
| `DISCOVER` | *(empty)* | Respond with locals |
| `DISCOVER_RESPONSE` | SessionInfo[] JSON | Upsert each |

### `sezam:broadcast` channel

| Envelope | Payload | Action |
|---|---|---|
| `BROADCAST` | `{from}:{message}` | Deliver to all local |
| `USER` | `{to}:{from}:{message}` | Find local user, deliver |
| `CHAT` | `{room}:{from}:{message}` | Deliver to all local |

## Key Files

| File | Purpose |
|---|---|
| `Data/Sessions.cs` | `ISession` interface |
| `Data/Messaging/SessionInfo.cs` | Universal session descriptor |
| `Data/Messaging/MessageBroadcaster.cs` | Redis Pub/Sub + protocol |
| `Data/Messaging/DistributedSessionRegistry.cs` | Unified query layer |
| `Data/Store.cs` | Messaging API + session storage |
| `Console/Session.cs` | `PublishSessionUpdate()`, `Deliver()` |
| `Console/Commands/CommandSet.cs` | `FindOnlineUser()`, `GetAllSessions()` |
