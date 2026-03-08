# Sezam Critical Fixes - Implementation Guide

## Quick Implementation Checklist

This document provides concrete code changes for Priority 1 issues that should be fixed immediately.

---

## Fix 1: DbContext Resource Disposal

### Current Code (Session.cs)
```csharp
public SezamDbContext Db = Store.GetNewContext();

public void Run()
{
    try
    {
        // ... main loop ...
    }
    finally
    {
        SysLog("Disconnected");
        OnFinish?.Invoke(this, null);
        thread = null;
    }
}
```

### Fixed Code
```csharp
public SezamDbContext Db { get; private set; }

public Session(ITerminal terminal)
{
    this.terminal = terminal;
    id = Guid.NewGuid();
    thread = new Thread(new ThreadStart(Run));
    commandSets = new Dictionary<Type, CommandSet>();
    NodeNo = 1;
    Db = Store.GetNewContext();  // Initialize here
}

public void Run()
{
    try
    {
        // ... main loop ...
    }
    catch (Exception e)
    {
        // ... existing catch blocks ...
    }
    finally
    {
        try
        {
            SysLog("Disconnected");
        }
        catch { }
        
        try
        {
            Db?.Dispose();
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error disposing DbContext: {ex.Message}");
        }
        
        try
        {
            OnFinish?.Invoke(this, null);
        }
        catch (Exception ex)
        {
            ErrorHandling.Handle(ex);
        }
        
        thread = null;
    }
}
```

---

## Fix 2: TcpClient and NetworkStream Disposal

### Current Code (TelnetTerminal.cs)
```csharp
public void Close()
{
    Out.Flush();
    if (tcpClient != null)
        tcpClient.Close();
}
```

### Fixed Code
```csharp
public void Close()
{
    try
    {
        Out?.Flush();
    }
    catch (Exception ex)
    {
        Debug.WriteLine($"Flush error: {ex.Message}");
    }
    
    try
    {
        Out?.Dispose();
    }
    catch (Exception ex)
    {
        Debug.WriteLine($"Out dispose error: {ex.Message}");
    }
    
    try
    {
        tcpClient?.Dispose();
    }
    catch (Exception ex)
    {
        Debug.WriteLine($"TcpClient dispose error: {ex.Message}");
    }
}
```

Or simplify with using pattern in TelnetTerminal constructor:
```csharp
// Consider storing tcpClient reference only for disposal
// But keep current StreamWriter approach for compatibility

// In Close():
if (tcpClient != null)
{
    try
    {
        tcpClient.Dispose();
    }
    catch { }
}
```

---

## Fix 3: Store Static Fields Thread Safety

### Current Code (Store.cs)
```csharp
private static IList<ISession> sessions;
private static string serverName;
private static string password;

public static IList<ISession> Sessions { get => sessions; set => sessions = value; }
public static string ServerName { get => serverName; set => serverName = value; }
public static string Password { get => password; set => password = value; }
```

### Fixed Code
```csharp
// Add volatile for string fields and private lock for list
private static volatile IList<ISession> sessions;
private static volatile string serverName;
private static volatile string password;

// Alternative: Thread-safe list property
private static readonly object _sessionLock = new object();
private static List<ISession> _sessionsList = new List<ISession>();

public static IList<ISession> Sessions
{
    get
    {
        lock (_sessionLock)
        {
            return new List<ISession>(_sessionsList);
        }
    }
    set
    {
        lock (_sessionLock)
        {
            _sessionsList.Clear();
            if (value != null)
                _sessionsList.AddRange(value);
        }
    }
}

public static string ServerName
{
    get { return serverName; }
    set { serverName = value; }
}

public static string Password
{
    get { return password; }
    set { password = value; }
}
```

---

## Fix 4: CommandSet Catalog Double-Checked Locking

### Current Code (CommandSet.cs)
```csharp
public Dictionary<string, object> Catalog
{
    get
    {
        // Happy path - NO LOCK
        var type = GetType();
        if (setCatalogs.Keys.Contains(type))
            return setCatalogs[type];

        // First access - with lock
        lock (setCatalogs)
        {
            var catalog = GetCatalog();
            setCatalogs.Add(type, catalog);  // CRASH if duplicate!
            return catalog;
        }
    }
}
```

### Fixed Code
```csharp
public Dictionary<string, object> Catalog
{
    get
    {
        var type = GetType();
        
        // Fast path without lock
        Dictionary<string, object> catalog;
        if (setCatalogs.TryGetValue(type, out catalog))
            return catalog;

        // Double-checked locking pattern
        lock (setCatalogs)
        {
            // Recheck after acquiring lock
            if (setCatalogs.TryGetValue(type, out catalog))
                return catalog;

            // Create and store
            catalog = GetCatalog();
            setCatalogs[type] = catalog;  // Use indexer, not Add()
            return catalog;
        }
    }
}
```

---

## Fix 5: OnSessionFinish Exception Safety

### Current Code (Server.cs)
```csharp
private void OnSessionFinish(object sender, EventArgs e)
{
    Session session = sender as Session;
    Debug.WriteLine(String.Format("SERVER: {0} finished", session));
    session.terminal.Close();
    lock (sessions)
    {
        sessions.Remove(session);
        PrintServerStatistics();  // Could throw!
    }
}
```

### Fixed Code
```csharp
private void OnSessionFinish(object sender, EventArgs e)
{
    Session session = sender as Session;
    
    // Outer try-catch to ensure something logs if everything fails
    try
    {
        try
        {
            Debug.WriteLine(String.Format("SERVER: {0} finished", session));
        }
        catch (Exception ex)
        {
            ErrorHandling.Handle(ex);
        }
        
        // Close terminal outside lock
        try
        {
            session?.terminal?.Close();
        }
        catch (Exception ex)
        {
            ErrorHandling.Handle(ex);
        }

        // Remove from list with full exception handling
        lock (sessions)
        {
            try
            {
                sessions.Remove(session);
            }
            catch (Exception ex)
            {
                ErrorHandling.Handle(ex);
            }
            
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

## Fix 6: Session Volatile Fields and Lazy Initialization

### Current Code (Session.cs)
```csharp
private CommandSet rootCommandSet;
public CommandSet currentCommandSet;

private void InputAndExecCmd()
{
    // Initialise root 1st time
    if (rootCommandSet == null)  // RACE CONDITION!
        rootCommandSet = GetCommandProcessor(CommandSet.RootType());

    if (currentCommandSet == null)
        currentCommandSet = rootCommandSet;
    
    // ...
}
```

### Fixed Code
```csharp
private volatile CommandSet rootCommandSet;
private volatile CommandSet currentCommandSet;

private readonly object _cmdSetLock = new object();

private void InputAndExecCmd()
{
    // Initialize root on first access (double-checked locking)
    if (rootCommandSet == null)
    {
        lock (_cmdSetLock)
        {
            if (rootCommandSet == null)
            {
                rootCommandSet = GetCommandProcessor(CommandSet.RootType());
            }
        }
    }

    if (currentCommandSet == null)
    {
        lock (_cmdSetLock)
        {
            if (currentCommandSet == null)
            {
                currentCommandSet = rootCommandSet;
            }
        }
    }

    string prompt = currentCommandSet?.GetPrompt() ?? ">";
    string cmd = terminal.PromptEdit(prompt + ">");

    if (terminal.Connected)
        ExecCmd(cmd);
}

// Alternative: Use Lazy<T> for cleaner code
private readonly Lazy<CommandSet> lazyRootCommandSet;
private volatile CommandSet currentCommandSet;

public Session(ITerminal terminal)
{
    // ... existing code ...
    lazyRootCommandSet = new Lazy<CommandSet>(
        () => GetCommandProcessor(CommandSet.RootType()),
        LazyThreadSafetyMode.ExecutionAndPublication
    );
}

private void InputAndExecCmd()
{
    var rootCommandSet = lazyRootCommandSet.Value;
    if (currentCommandSet == null)
        currentCommandSet = rootCommandSet;
    
    // ...
}
```

---

## Fix 7: Session.Close() with Timeout and Null Checks

### Current Code (Session.cs)
```csharp
public void Close()
{
    if (thread != null && thread.IsAlive)
    {
        thread.Interrupt();
        thread.Join();  // HANGS FOREVER!
    }
    terminal.Close();  // Could throw
}
```

### Fixed Code
```csharp
public void Close()
{
    const int ThreadJoinTimeoutMs = 5000;
    
    // Close thread
    try
    {
        if (thread != null && thread.IsAlive)
        {
            thread.Interrupt();
            
            if (!thread.Join(ThreadJoinTimeoutMs))
            {
                // Thread didn't stop in time
                SysLog("Warning: Session thread did not terminate gracefully");
                Debug.WriteLine($"Session thread {id} hung for >5s");
            }
        }
    }
    catch (Exception ex)
    {
        ErrorHandling.Handle(ex);
    }

    // Close terminal
    try
    {
        terminal?.Close();
    }
    catch (Exception ex)
    {
        Debug.WriteLine($"Error closing terminal: {ex.Message}");
        ErrorHandling.Handle(ex);
    }
}
```

---

## Fix 8: Error Loop Prevention

### Current Code (Session.cs)
```csharp
catch (Exception e)
{
    terminal.Line("Blimey! System Error: {0}", e.Message);
    ErrorHandling.Handle(e);
    continue;  // INFINITE LOOP RISK!
}
```

### Fixed Code
```csharp
private int consecutiveExceptionCount = 0;
private const int MaxConsecutiveExceptions = 3;

// In Run() loop:
catch (TerminalException e)
{
    switch (e.Code)
    {
        case TerminalException.CodeType.ClientDisconnected:
            consecutiveExceptionCount = 0;  // Reset on expected disconnect
            throw;
        case TerminalException.CodeType.UserOutputInterrupted:
            consecutiveExceptionCount = 0;  // Reset on expected event
            continue;
    }
}
catch (ArgumentException e)
{
    terminal.Line("* " + e.Message);
    consecutiveExceptionCount = 0;  // Expected user error, reset
    continue;
}
catch (NotImplementedException e)
{
    terminal.Line("* " + e.Message);
    consecutiveExceptionCount = 0;  // Expected feature placeholder
    continue;
}
catch (Exception e)
{
    consecutiveExceptionCount++;
    terminal.Line("System Error: {0}", e.Message);
    ErrorHandling.Handle(e);
    
    if (consecutiveExceptionCount > MaxConsecutiveExceptions)
    {
        terminal.Line("Too many errors. Disconnecting.");
        throw new TerminalException(TerminalException.CodeType.ClientDisconnected);
    }
    
    // Brief delay to prevent rapid spinning
    Thread.Sleep(100);
    continue;
}
```

---

## Fix 9: SaveChangesAsync Fire-and-Forget

### Current Code (Session.cs)
```csharp
User.LastCall = LoginTime;
Db.SaveChangesAsync();  // Fire and forget!
```

### Fixed Code
```csharp
public User Login()
{
    // ... existing login code ...
    if (user != null)
    {
        // ... existing code ...
        User.LastCall = LoginTime;
        
        // Synchronous save with error handling
        try
        {
            Db.SaveChanges();
        }
        catch (DbUpdateException ex)
        {
            Debug.WriteLine($"Login save failed: {ex.Message}");
            // Don't fail login, but log the issue
            ErrorHandling.Handle(ex);
        }
    }
    return user;
}

// Or if async is required:
public async Task<User> LoginAsync()
{
    // ... async version ...
    try
    {
        await Db.SaveChangesAsync();
    }
    catch (DbUpdateException ex)
    {
        SysLog("Failed to record last login time");
        ErrorHandling.Handle(ex);
        // Don't throw - login succeeds even if audit failed
    }
}
```

---

## Implementation Order

### Phase 1: Resource Cleanup (2 hours)
1. Fix DbContext disposal (Fix 1)
2. Fix TcpClient disposal (Fix 2)
3. Fix OnSessionFinish exception safety (Fix 5)
4. Test with connection stress test

### Phase 2: Thread Safety (3 hours)
5. Fix Store volatile fields (Fix 3)
6. Fix CommandSet catalog locking (Fix 4)
7. Fix Session volatile fields (Fix 6)
8. Test with concurrent command execution

### Phase 3: Stability (2 hours)
9. Fix Session.Close() timeout (Fix 7)
10. Fix error loop prevention (Fix 8)
11. Fix SaveChangesAsync (Fix 9)
12. Test with disconnect/error scenarios

### Phase 4: Testing (4 hours)
- Load test with 100+ concurrent connections
- Chaos test: random disconnects, errors
- Memory/handle leak detection
- Verify no deadlocks under stress

---

## Verification Scripts

### Check Resource Leaks (Windows)
```batch
REM Run in elevated prompt
tasklist /v | findstr "Sezam.Telnet"
REM Note initial handle count

REM Connect/disconnect 100 times, then check again
REM Handle count should not grow significantly
```

### Check Resource Leaks (Linux)
```bash
# Monitor open file descriptors
lsof -p $(pidof Sezam.Telnet) | wc -l

# Should stabilize after connect/disconnect cycles
# 
# Run:
# for i in {1..100}; do 
#   timeout 1 telnet localhost 2023 
# done

# Check again - should be same as initial
```

### Load Test
```bash
# Using Apache ab or similar
ab -n 1000 -c 50 telnet://localhost:2023
```

---

## Tags for Code Review

Mark these changes with comments for easy tracking:

```csharp
// ROBUSTNESS: Fix #1 - DbContext disposal
// ROBUSTNESS: Fix #2 - TcpClient disposal
// ROBUSTNESS: Fix #3 - Store thread safety
// ROBUSTNESS: Fix #4 - Catalog locking
// ROBUSTNESS: Fix #5 - Exception safety
// ROBUSTNESS: Fix #6 - Volatile fields
// ROBUSTNESS: Fix #7 - Timeout with null checks
// ROBUSTNESS: Fix #8 - Error prevention
// ROBUSTNESS: Fix #9 - SaveChanges error handling
```

This allows tracking completion and enables grep:
```bash
grep -r "ROBUSTNESS:" --include="*.cs"
```
