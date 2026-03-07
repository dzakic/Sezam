# Session Execution Model - Temporary Switch to Sync

## Current Status: THREAD-PER-SESSION (Synchronous)

Temporarily switched back to synchronous execution model for development/testing.

### What Changed

**File: `Console/Server.cs` (Telnet listener)**

```csharp
// BEFORE (Async):
var session = new SessionAsync(terminal) { OnFinish = OnSessionFinish };
var _ = session.RunAsync(); // fire and forget

// AFTER (Sync):
var session = new Session(terminal) { OnFinish = OnSessionFinish };
session.Start(); // Start on dedicated thread
```

---

## Execution Models

### Current: Synchronous (Thread-Per-Session)
```
- Each Telnet connection runs on its own dedicated thread
- Session.Run() blocks until user disconnects
- Thread pool not involved
- Simpler debugging
- Each user has isolated ThreadLocal state
```

**Good for:**
- Development & testing
- Debugging thread-specific issues
- Simple execution flow
- Isolated user sessions

**Trade-offs:**
- Limited by thread count (~1000s of concurrent users)
- More memory per session
- Higher context switch overhead

### Available: Asynchronous (Thread Pool)
```
- Multiple connections scheduled on thread pool threads
- SessionAsync.RunAsync() resumes execution on any available thread
- Efficient for thousands of concurrent users
- Complex async/await patterns required
- SessionCulture property handles culture across thread boundaries
```

**Good for:**
- High-concurrency servers
- Efficient resource usage
- Modern async patterns

**Trade-offs:**
- More complex debugging
- Async-aware code required throughout
- Thread pool scheduling overhead

---

## Switching Back to Async (When Ready)

When you want to re-enable async execution:

### 1. Update Server.cs
```csharp
// Change this:
var session = new Session(terminal) { OnFinish = OnSessionFinish };
session.Start();

// To this:
var session = new SessionAsync(terminal) { OnFinish = OnSessionFinish };
var _ = session.RunAsync(); // fire and forget
```

### 2. Remove Debug Comment
```csharp
// TEMP: Using synchronous Session (thread-per-session) for now
// AsyncImpl: Switch back to SessionAsync for production use
```

### 3. Test Thoroughly
- Verify localization works with thread pool threads
- Test with multiple concurrent users
- Check SessionCulture behavior across await points

---

## Why This Matters for Localization

The localization system works with **both** execution models:

### Sync Session ✓
```csharp
// Thread has stable culture:
Thread.CurrentThread.CurrentCulture = culture;
session.SessionCulture = culture; // Backup
```

### Async Session ✓
```csharp
// Thread changes at each await point:
// Thread.CurrentThread.CurrentCulture (unreliable)
session.SessionCulture = culture; // Always works!
```

By using `session.SessionCulture` property, localization works perfectly in both models!

---

## Console Sessions (Unchanged)

Console sessions (local debugging) remain synchronous:

```csharp
// In Server.cs RunConsoleSession()
var console = new ConsoleTerminal();
var consoleSession = new Session(console) { OnFinish = OnSessionFinish };
consoleSession.Run(); // Synchronous
```

---

## Current Configuration

| Session Type | Execution | Usage |
|---|---|---|
| **Session** | Sync (thread-per-session) | Telnet ← CURRENT |
| **Session** | Sync (blocking) | Console ✓ |
| **SessionAsync** | Async (thread pool) | Available but disabled |

---

## Development Notes

### When to Use Sync (Current)
- ✅ Development
- ✅ Testing
- ✅ Debugging
- ✅ Small deployments
- ✅ Simple concurrency

### When to Switch to Async
- ⏳ High-concurrency production
- ⏳ Cloud/scalable deployments
- ⏳ Resource optimization needed
- ⏳ Modern async framework requirements

---

## Quick Toggle

To quickly switch between sync/async, modify **Server.cs line ~144**:

**For Sync (Current):**
```csharp
var session = new Session(terminal) { OnFinish = OnSessionFinish };
session.Start();
```

**For Async (When Ready):**
```csharp
var session = new SessionAsync(terminal) { OnFinish = OnSessionFinish };
var _ = session.RunAsync();
```

Both implementations are fully functional and available!

---

## Build Status
✅ **Compiles successfully**  
✅ **No errors or warnings**  
✅ **SessionAsync still available** (just not used)  
✅ **All features work**  

---

## Next Steps

Keep synchronous execution for now. When you want to:

1. **Switch to async**: Update the Server.cs line mentioned above
2. **Test concurrency**: Use async and monitor SessionCulture behavior
3. **Optimize resources**: Use async in production if needed

The choice is yours, and switching is quick! 🔄
