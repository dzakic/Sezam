# Session MessageBroadcaster Centralization

## Change Summary

Refactored `Session.cs` to use the global `Data.Store.MessageBroadcaster` singleton instead of maintaining a local field.

## What Changed

### Session.cs
**Before:**
```csharp
private MessageBroadcaster _messageBroadcaster;
public MessageBroadcaster MessageBroadcaster
{
    get => _messageBroadcaster;
    set => _messageBroadcaster = value;
}
```

**After:**
```csharp
public MessageBroadcaster MessageBroadcaster => Data.Store.MessageBroadcaster;
```

**Impact:**
- ✅ Removed local field entirely
- ✅ Property now read-only (getter only)
- ✅ Always references global singleton
- ✅ Automatically gets latest broadcaster state

### All References Updated

All internal references to `_messageBroadcaster` changed to `Data.Store.MessageBroadcaster`:
- In `Run()` finally block - broadcasts session disconnect
- In `WelcomeAndLogin()` - broadcasts session join
- In both cases, broadcasts to other nodes in the cluster

### Server.cs Cleanup

Removed redundant setter calls that are no longer needed:
```csharp
// Removed these (no longer valid):
consoleSession.MessageBroadcaster = Data.Store.MessageBroadcaster;
session.MessageBroadcaster = Data.Store.MessageBroadcaster;
```

Since the property is now read-only and always references the global, there's no need to set it.

## Benefits

✅ **Single Source of Truth** - All sessions use the same broadcaster instance
✅ **Simplified Code** - No local field management
✅ **Thread-Safe** - Global singleton is thread-safe
✅ **Consistent** - All sessions get updates automatically
✅ **Read-Only** - Property can't be accidentally set to wrong value

## Technical Details

### Data Flow

```
Server.InitializeAsync()
  └─ Creates MessageBroadcaster
  └─ Stores in Data.Store.MessageBroadcaster

Session.WelcomeAndLogin()
  └─ Accesses via: Data.Store.MessageBroadcaster
  └─ Broadcasts join event to cluster

Session.Run() finally block
  └─ Accesses via: Data.Store.MessageBroadcaster  
  └─ Broadcasts leave event to cluster
```

### Property Access

The property is now an expression-bodied property:
```csharp
public MessageBroadcaster MessageBroadcaster => Data.Store.MessageBroadcaster;
```

This always returns the current global broadcaster, making the property a true proxy to the global singleton.

## Build Status

✅ **Build Successful** - All changes compile without errors

## Files Modified

1. `Console/Session.cs` - Updated property and all references
2. `Console/Server.cs` - Removed redundant setter calls

## Architectural Impact

This completes the consolidation pattern:
- Database context: `Data.Store` (centralized)
- Configuration: `Data.Store` (centralized)
- Redis config: `Data.Store` (centralized)
- **MessageBroadcaster: `Data.Store` (centralized)** ← New
- Sessions: `Data.Store.Sessions` (centralized)

All global application state is now accessible through `Data.Store`, following a consistent pattern across the system.
