# Sezam Session Management & Robustness Analysis

## Executive Summary
The Sezam system uses a thread-per-session model with moderate thread safety practices. While basic locking is in place for shared state, several areas present risks for data corruption, resource leaks, connection loss, and session state inconsistencies.

---

## Critical Issues

### 1. **DbContext Resource Leak** ⚠️ HIGH
**Location**: [Console/Session.cs](Console/Session.cs#L241)
**Issue**: DbContext is created once per session but never disposed.
```csharp
public SezamDbContext Db = Store.GetNewContext();
```
**Concern**: 
- Database connections held indefinitely
- Memory leaks for long-running sessions
- Possible connection pool exhaustion
- EF Core change tracking not cleaned up

**Recommendation**:
```csharp
// In Session constructor:
public Session(ITerminal terminal)
{
    this.terminal = terminal;
    // ... other init ...
    Db = Store.GetNewContext();
}

// In finally block of Run() method:
finally
{
    try { Db?.Dispose(); } catch { }
    // ... existing cleanup ...
}
```

---

### 2. **TcpClient/NetworkStream Not Disposed** ⚠️ HIGH
**Location**: [Console/Terminal/TelnetTerminal.cs](Console/Terminal/TelnetTerminal.cs#L260-265)
**Issue**: Close() only flushes, doesn't dispose TcpClient or NetworkStream
```csharp
public void Close()
{
    Out.Flush();
    if (tcpClient != null)
        tcpClient.Close();  // Better: use Dispose() in using
}
```
**Concern**:
- Socket handles leak
- StreamWriter not disposed (buffer may not flush completely)
- Program resource limits reached under continuous load

**Recommendation**:
```csharp
public void Close()
{
    try
    {
        Out?.Flush();
        Out?.Dispose();
    }
    catch { }
    finally
    {
        tcpClient?.Dispose();
    }
}
```

---

### 3. **Race Condition in CommandSet Catalog Lookup** ⚠️ MEDIUM
**Location**: [Console/Commands/CommandSet.cs](Console/Commands/CommandSet.cs#L167-182)
**Issue**: Lock is only held during first initialization, not during subsequent reads
```csharp
public Dictionary<string, object> Catalog
{
    get
    {
        // Happy path - NO LOCK (race condition!)
        var type = GetType();
        if (setCatalogs.Keys.Contains(type))
            return setCatalogs[type];

        // First access - with lock
        lock (setCatalogs)
        {
            var catalog = GetCatalog();
            setCatalogs.Add(type, catalog);
            return catalog;
        }
    }
}
```
**Concern**:
- Two threads checking same type simultaneously might both enter init path
- `SetCatalogs.Add()` would throw duplicate key exception
- Session crashes during command lookup

**Recommendation**:
```csharp
public Dictionary<string, object> Catalog
{
    get
    {
        var type = GetType();
        Dictionary<string, object> catalog;
        
        if (setCatalogs.TryGetValue(type, out catalog))
            return catalog;
        
        lock (setCatalogs)
        {
            // Double-check pattern
            if (setCatalogs.TryGetValue(type, out catalog))
                return catalog;
            
            catalog = GetCatalog();
            setCatalogs[type] = catalog;  // Use index setter
            return catalog;
        }
    }
}
```

---

### 4. **Store Static Fields Not Thread-Safe** ⚠️ MEDIUM
**Location**: [Data/Store.cs](Data/Store.cs#L34-36)
**Issue**: Static fields are mutable without synchronization
```csharp
private static IList<ISession> sessions;
private static string serverName;
private static string password;

public static IList<ISession> Sessions { get => sessions; set => sessions = value; }
public static string ServerName { get => serverName; set => serverName = value; }
public static string Password { get => password; set => password = value; }
```
**Concern**:
- Visibility issues between threads (need `volatile` or locking)
- Race conditions during startup when setting config
- Session list could see stale references
- Especially problematic: `Sessions` is replaced entirely (not thread-safe)

**Recommendation**:
```csharp
private static volatile IList<ISession> sessions;
private static volatile string serverName;
private static volatile string password;

// For Sessions list, use thread-safe collection or proper locking:
// BETTER: Use ConcurrentBag or List with lock everywhere
private static readonly object _sessionsLock = new object();
private static List<ISession> sessions;

public static IList<ISession> Sessions
{
    get { lock (_sessionsLock) return new List<ISession>(sessions); }
    set { lock (_sessionsLock) sessions = value ?? new List<ISession>(); }
}
```

---

### 5. **CommandLine Token Mutation** ⚠️ MEDIUM
**Location**: [Console/Commands/CommandLine.cs](Console/Commands/CommandLine.cs#L33-41)
**Issue**: Tokens list is modified during iteration/access
```csharp
public string GetToken(string requiredValue = null)
{
    if (IsEmpty())
        if (string.IsNullOrEmpty(requiredValue))
            return string.Empty;
        else
            throw new ArgumentException("Required parameter missing: " + requiredValue);
    string token = tokens[0];
    tokens.RemoveAt(0);  // Mutates list!
    return token;
}
```
**Concern**:
- If CommandLine state is somehow cached/reused, mutation breaks it
- Complex commands accessing tokens while being consumed could get bad state
- Nested command calls might not work correctly

**Recommendation**:
```csharp
public class CommandLine
{
    private int currentIndex = 0;
    
    public string GetToken(string requiredValue = null)
    {
        if (currentIndex >= tokens.Count)
        {
            if (string.IsNullOrEmpty(requiredValue))
                return string.Empty;
            throw new ArgumentException("Required parameter missing: " + requiredValue);
        }
        return tokens[currentIndex++];
    }
    
    public void Reset() => currentIndex = 0;
}
```

---

### 6. **Session Exception Handlers Could Break Cleanup** ⚠️ MEDIUM
**Location**: [Console/Server.cs](Console/Server.cs#L146-158)
**Issue**: OnSessionFinish event handler exception could prevent cleanup
```csharp
private void OnSessionFinish(object sender, EventArgs e)
{
    Session session = sender as Session;
    Debug.WriteLine(String.Format("SERVER: {0} finished", session));
    session.terminal.Close();
    lock (sessions)
    {
        sessions.Remove(session);
        PrintServerStatistics();
        // If PrintServerStatistics() throws, sessions stays locked!
    }
}
```
**Concern**:
- PrintServerStatistics might throw
- Lock not released, deadlock on next session
- Session not removed from list

**Recommendation**:
```csharp
private void OnSessionFinish(object sender, EventArgs e)
{
    Session session = sender as Session;
    try
    {
        try
        {
            session?.terminal?.Close();
        }
        catch (Exception ex)
        {
            ErrorHandling.Handle(ex);
        }
        
        lock (sessions)
        {
            sessions.Remove(session);
            try
            {
                PrintServerStatistics();
            }
            catch (Exception ex)
            {
                ErrorHandling.Handle(ex);
            }
        }
    }
    catch (Exception ex)
    {
        ErrorHandling.Handle(ex);
    }
}
```

---

### 7. **Session State Not Volatile** ⚠️ MEDIUM
**Location**: [Console/Session.cs](Console/Session.cs#L233-241)
**Issue**: Mutable public/private fields without synchronization
```csharp
public CommandSet currentCommandSet;  // Directly modified without sync
private CommandSet rootCommandSet;     // Lazily initialized without sync
```
**Concern**:
- Thread visibility issues in .NET (must use volatile or locking)
- Check-then-act races: `if (rootCommandSet == null)` could be true for multiple threads
- Multi-command transaction could see partial state

**Recommendation**:
```csharp
private volatile CommandSet rootCommandSet;
private volatile CommandSet currentCommandSet;

// For initialization:
if (rootCommandSet == null)
{
    lock (this)  // or use lazy<T>
    {
        if (rootCommandSet == null)
            rootCommandSet = GetCommandProcessor(CommandSet.RootType());
    }
}
```

---

### 8. **TelnetTerminal Input Buffer Race Condition** ⚠️ MEDIUM
**Location**: [Console/Terminal/TelnetTerminal.cs](Console/Terminal/TelnetTerminal.cs#L271-282)
**Issue**: Manual input buffer with instance variables, no synchronization
```csharp
private readonly byte[] inputBytes = new byte[256];
private int inputLen = 0;
private int inputPos = 0;

private void FillInputBuffer()
{
    if (inputPos >= inputLen)
    {
        inputLen = netStream.Read(inputBytes, 0, inputBytes.Length);
        // Race: Another thread could read inputLen between check and use
        // ...
    }
}
```
**Concern**:
- If multiple threads somehow access same TelnetTerminal, corruption
- inputLen/inputPos could be read as partially-written values
- Network stream is not thread-safe for concurrent reads

**Recommendation**:
Per-thread terminals are OK, but add documentation. Consider:
```csharp
private readonly object _inputBufferLock = new object();
// ... use lock when accessing inputLen, inputPos together
```

---

### 9. **No Graceful Shutdown on Exception** ⚠️ MEDIUM
**Location**: [Console/Session.cs](Console/Session.cs#L68-77)
**Issue**: Outer catch blocks email exception but don't signal disconnect
```csharp
catch (Exception e)
{
    terminal.Line("Blimey! System Error: {0}", e.Message);
    ErrorHandling.Handle(e);
    continue;  // Continues loop, might spin on same error
}
```
**Concern**:
- If error is repeatable, session spins in tight loop
- High CPU usage
- No exponential backoff or break on repeated errors

**Recommendation**:
```csharp
private int consecutiveErrors = 0;
const int MaxConsecutiveErrors = 3;

catch (Exception e)
{
    terminal.Line("System Error: {0}", e.Message);
    ErrorHandling.Handle(e);
    consecutiveErrors++;
    if (consecutiveErrors > MaxConsecutiveErrors)
    {
        terminal.Line("Too many errors. Disconnecting.");
        throw new TerminalException(TerminalException.CodeType.ClientDisconnected);
    }
    continue;
}
```

---

## Moderate Issues

### 10. **No SaveChanges Error Recovery** ⚠️ MEDIUM
**Location**: [Console/Session.cs](Console/Session.cs#L111)
```csharp
Db.SaveChangesAsync();  // No await, no error handling, returns Task
```
**Issue**: 
- SaveChangesAsync is fire-and-forget
- Database errors silently ignored
- Potential data loss on concurrency conflicts

**Recommendation**:
```csharp
try
{
    await Db.SaveChangesAsync();
}
catch (DbUpdateConcurrencyException ex)
{
    SysLog("Concurrency error: {0}", ex.Message);
    // Reload from DB or notify user
}
catch (Exception ex)
{
    SysLog("Save error: {0}", ex.Message);
    ErrorHandling.Handle(ex);
}
```

---

### 11. **Missing Null Checks in Session.Close()** ⚠️ MEDIUM
**Location**: [Console/Session.cs](Console/Session.cs#L217-223)
```csharp
public void Close()
{
    if (thread != null && thread.IsAlive)
    {
        thread.Interrupt();
        thread.Join();  // Could hang if thread not responsive
    }
    terminal.Close();
}
```
**Issue**:
- `Thread.Join()` with no timeout blocks forever if thread hangs
- `terminal` could be null by this point

**Recommendation**:
```csharp
public void Close()
{
    try
    {
        if (thread != null && thread.IsAlive)
        {
            thread.Interrupt();
            if (!thread.Join(TimeSpan.FromSeconds(5)))
            {
                // Thread didn't stop, log warning
                SysLog("Warning: Session thread did not terminate");
            }
        }
    }
    catch (Exception ex)
    {
        ErrorHandling.Handle(ex);
    }
    
    try
    {
        terminal?.Close();
    }
    catch (Exception ex)
    {
        ErrorHandling.Handle(ex);
    }
}
```

---

### 12. **GetUser Query Not Cached (N+1)** ⚠️ LOW-MEDIUM
**Location**: [Console/Session.cs](Console/Session.cs#L130)
```csharp
public User GetUser(string username)
{
    return Db.Users.Where(u => u.Username == username).FirstOrDefault();
}
```
**Issue**:
- Called multiple times, each query hits database
- Could cache user list in memory
- Especially during login retry loop

**Recommendation**:
```csharp
private Dictionary<string, User> userCache;

public User GetUser(string username)
{
    if (userCache == null)
        userCache = Db.Users.ToDictionary(u => u.Username);
    
    return userCache.ContainsKey(username) ? userCache[username] : null;
}
```

---

### 13. **Server Stop Race Condition** ⚠️ LOW-MEDIUM
**Location**: [Console/Server.cs](Console/Server.cs#L163-175)
```csharp
public void Stop()
{
    listener?.Stop();
    // ...
    foreach (Session session in sessions.ToList())
    {
        Debug.Write(".");
        session.Close();  // No timeout, blocks main thread
    }
}
```
**Issue**:
- `session.Close()` calls `thread.Join()` with no timeout
- If hung session exists, server hangs during shutdown
- Multiple session closes could deadlock

**Recommendation**: Add timeout per session, use tasks:
```csharp
public void Stop()
{
    listener?.Stop();
    foreach (var session in sessions.ToList())
    {
        try
        {
            session.Close();  // Already has 5s timeout (recommended above)
        }
        catch { }
    }
    // Wait for all threads
    mainThread?.Join(TimeSpan.FromSeconds(10));
}
```

---

## Best Practices & Scalability

### 14. **Thread-Per-Request Not Scalable** ⚠️ INFO
**Issue**: Current architecture creates one thread per session
```csharp
thread = new Thread(new ThreadStart(Run));
```
**Impact**:
- OS limits ~1000-10000 threads depending on stack size
- High context switching overhead
- Not suitable for thousands of concurrent users

**Recommendation** (Long term):
- Migrate to async/await with Task-based concurrency
- Use connection pooling
- Example pattern:
```csharp
public async Task RunAsync()
{
    try
    {
        await WelcomeAndLoginAsync();
        while (terminal.Connected)
        {
            await InputAndExecCmdAsync();
        }
    }
    finally
    {
        SysLog("Disconnected");
        OnFinish?.Invoke(this, null);
    }
}
```

---

### 15. **No Connection Timeout** ⚠️ LOW
**Issue**: Idle connections never timeout
```csharp
// In PromptEdit:
while (c != '\r')
{
    c = ReadChar();  // Blocks forever waiting for input
}
```
**Impact**:
- Slow clients or abandoned connections hold session alive
- Resource waste

**Recommendation**:
```csharp
public string PromptEdit(string prompt = "", InputFlags flags = 0, int timeoutMs = 300000)
{
    using (var cts = new CancellationTokenSource(timeoutMs))
    {
        return await PromptEditAsync(prompt, flags, cts.Token);
    }
}
```

---

### 16. **No Input Size Limits** ⚠️ LOW
**Issue**: Command line can be arbitrarily long
```csharp
while (c != '\r')
{
    line += c;  // No length check
}
```
**Impact**:
- Memory exhaustion attack via huge input
- regex/reflection overhead on large strings

**Recommendation**:
```csharp
const int MaxCommandLength = 256;
if (line.Length >= MaxCommandLength)
{
    Out.Write("Command too long");
    Out.WriteLine();
    return "";
}
```

---

## Session Reuse Considerations

### Current Design: **New Session Per Connection** ✓
The code assumes sessions are not reused. This is correct and simplifies safety. However:

**If session reuse were considered**:
1. ✅ DbContext disposal would fail (leak grows)
2. ✅ User state stays from previous user unless explicitly cleared
3. ✅ CommandSet cache persists across users
4. ✅ Terminal state (page size, buffer) persists

**Recommendation**: Keep current design, never reuse sessions.

---

## Summary of Recommended Changes

### Priority 1 (Critical - Do First)
1. Dispose DbContext in Session.Run() finally block
2. Dispose TcpClient/StreamWriter properly in TelnetTerminal.Close()
3. Fix Store static field visibility with volatile keyword
4. Fix CommandSet catalog double-checked locking pattern
5. Add exception handling to OnSessionFinish event handler

### Priority 2 (High)
6. Use lazy initialization or lock for rootCommandSet/currentCommandSet
7. Fix TelnetTerminal null reference in Close()
8. Add timeout to session.Close() and server.Stop()
9. Add error count threshold in Session.Run() loop

### Priority 3 (Medium)
10. Improve SaveChangesAsync error handling
11. Add input length limits
12. Implement connection idle timeout
13. Cache User lookups during session
14. Document thread-safety assumptions

### Priority 4 (Scalability)
15. (Future) Migrate to async/await model
16. (Future) Implement connection pooling

---

## Testing Recommendations

```csharp
// Unit test for catalog thread safety:
[Test]
public void CommandSetCatalog_ConcurrentAccess_NoExceptions()
{
    var session = new Session(new MockTerminal());
    var cmdSet = new TestCommandSet(session);
    
    var tasks = Enumerable.Range(0, 100)
        .Select(_ => Task.Run(() => cmdSet.Catalog))
        .ToArray();
    
    Task.WaitAll(tasks);
    Assert.Pass();
}

// Integration test for session cleanup:
[Test]
public void SessionDisconnect_AllResourcesDisposed()
{
    var session = new Session(new MockTerminal());
    session.Start();
    
    // Simulate disconnect
    Thread.Sleep(100);
    session.Close();
    
    // Verify no leaked handles (process explorer check)
}
```

---

## References
- [Microsoft: Thread Safety in .NET](https://docs.microsoft.com/en-us/dotnet/standard/threading/managed-threading-basics)
- [DbContext Lifetime and Disposal](https://docs.microsoft.com/en-us/ef/core/dbcontext-configuration/)
- [Async/Await Best Practices](https://docs.microsoft.com/en-us/archive/msdn-magazine/2013/march/async-await-best-practices-in-asynchronous-programming)
- OWASP: [DoS via Resource Exhaustion](https://owasp.org/www-community/attacks/Denial_of_Service)
