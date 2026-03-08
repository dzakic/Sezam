# Structured Logging Setup - .NET 10 Best Practices

## Overview

Replaced old `System.Diagnostics.Trace` approach with modern `Microsoft.Extensions.Logging` for:
- ✅ Colored console output
- ✅ Log level hierarchy (Error, Warning, Information, Debug, Trace)
- ✅ Runtime filtering capability
- ✅ Structured logging with scopes
- ✅ Integration with .NET hosting framework

## TelnetServer.cs Changes

### Before
```csharp
Trace.Listeners.Add(new TextWriterTraceListener(System.Console.Out));
// No color, no hierarchy, no runtime filtering
```

### After
```csharp
builder.Logging
    .ClearProviders()
    .AddConsole(options =>
    {
        options.IncludeScopes = true;
        options.TimestampFormat = "HH:mm:ss ";
    })
    .SetMinimumLevel(LogLevel.Debug);  // Capture Debug and above
```

## Log Levels (Hierarchy)

From least to most severe:
1. **Trace** - Very detailed diagnostic information
2. **Debug** - Detailed information for debugging
3. **Information** - General informational messages (default)
4. **Warning** - Warning messages for potential issues
5. **Error** - Error messages for recoverable errors
6. **Critical** - Critical errors for unrecoverable situations
7. **None** - Disable logging

## How to Use in Your Code

### Inject ILogger

**In Services/Classes:**
```csharp
public class MyService
{
    private readonly ILogger<MyService> logger;
    
    public MyService(ILogger<MyService> logger)
    {
        this.logger = logger;
    }
    
    public void DoWork()
    {
        logger.LogInformation("Starting work...");
        logger.LogDebug("Debug detail: {Detail}", someValue);
        logger.LogWarning("Warning: {Issue}", issue);
        logger.LogError(ex, "Error occurred: {Message}", ex.Message);
    }
}
```

### In Session.cs

**Replace:**
```csharp
Trace.TraceInformation("Session welcome on {0}", terminal.Id);
```

**With:**
```csharp
public class Session : ISession
{
    private readonly ILogger<Session> logger;
    
    public Session(ITerminal terminal, ILogger<Session> logger)
    {
        this.terminal = terminal;
        this.logger = logger;
        // ... rest of constructor
    }
    
    private void WelcomeAndLogin()
    {
        logger.LogInformation("Session welcome on {TerminalId}", terminal.Id);
        logger.LogDebug("Assigned session ID: {SessionId}", Id);
    }
}
```

### In CommandSet/Commands

**Replace:**
```csharp
Debug.WriteLine("Command executed: {0}", cmd);
```

**With:**
```csharp
public class MyCommand : CommandSet
{
    private readonly ILogger<MyCommand> logger;
    
    public MyCommand(Session session, ILogger<MyCommand> logger) : base(session)
    {
        this.logger = logger;
    }
    
    [Command("mycommand")]
    public async Task MyCommand()
    {
        logger.LogInformation("Executing MyCommand for user {Username}", session.Username);
        logger.LogDebug("Command parameters: {Params}", parameters);
    }
}
```

## Runtime Filtering via appsettings.json

**Create appsettings.json with logging configuration:**
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Sezam": "Debug",
      "Sezam.Commands": "Debug",
      "Sezam.Console": "Information",
      "Sezam.Data": "Debug"
    },
    "Console": {
      "IncludeScopes": true,
      "TimestampFormat": "yyyy-MM-dd HH:mm:ss "
    }
  }
}
```

### What This Does

- `Sezam` namespace: Show Debug and above (very detailed)
- `Sezam.Console`: Show Information and above (less verbose)
- `Sezam.Commands`: Show Debug and above (detailed command execution)
- `Microsoft`: Show Warning and above (suppress framework details)

## Environment-Specific Configuration

### Development (appsettings.Development.json)
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Sezam": "Debug"
    }
  }
}
```

### Production (appsettings.json)
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Sezam": "Information"
    }
  }
}
```

## Example Output

With the new logging setup, you'll see:

```
info: Sezam.Console.Server[0]
      Listener started on 0.0.0.0:2023
dbug: Sezam.Console.Session[0]
      Session welcome on telnet://192.168.1.100:12345
info: Sezam.Console.Session[0]
      User authenticated: alice
warn: Sezam.Commands.Mail[0]
      Mailbox quota exceeded
fail: Sezam.Console.Session[0]
      Connection lost: RemoteDisconnected
```

Color-coded:
- 🟩 Green: Information
- 🟦 Blue: Debug
- 🟨 Yellow: Warning
- 🟥 Red: Error

## Structured Logging with Scopes

```csharp
using (logger.BeginScope("User: {Username}", session.Username))
{
    logger.LogInformation("Processing command");
    logger.LogDebug("Command details: {Details}", cmd);
    // All logs within this scope include the username
}
```

Output:
```
info: Sezam.Console.Session[0]
      => User: alice
      Processing command
dbug: Sezam.Console.Session[0]
      => User: alice
      Command details: ...
```

## Migration Checklist

When replacing old logging throughout the code:

- [ ] Replace `Trace.TraceInformation()` with `logger.LogInformation()`
- [ ] Replace `Debug.WriteLine()` with `logger.LogDebug()`
- [ ] Add `ILogger<T>` injection to classes
- [ ] Update exception logging: `logger.LogError(ex, "Message")`
- [ ] Remove old `System.Diagnostics.Trace` usage
- [ ] Configure appsettings.json logging levels
- [ ] Test with different LogLevel settings

## Benefits

✅ **Colored Output** - Easy to scan logs visually
✅ **Hierarchy** - Control verbosity per namespace
✅ **Runtime Filtering** - Change log levels without recompiling
✅ **Structured** - Supports scopes and context
✅ **Async-Friendly** - Works well with async/await
✅ **Framework Integration** - Consistent with .NET hosting
✅ **Multiple Providers** - Can add file, event log, etc. logging

## Example: Complete Migration

### Session.cs - Before
```csharp
public class Session : ISession
{
    public async Task Run()
    {
        try
        {
            Debug.WriteLine($"Session welcome on {terminal.Id}");
            Trace.TraceInformation("Connected");
            // ...
        }
        catch (Exception e)
        {
            Debug.WriteLine($"Error: {e.Message}");
        }
    }
}
```

### Session.cs - After
```csharp
public class Session : ISession
{
    private readonly ILogger<Session> logger;
    
    public Session(ITerminal terminal, ILogger<Session> logger)
    {
        this.terminal = terminal;
        this.logger = logger;
        // ...
    }
    
    public async Task Run()
    {
        try
        {
            logger.LogInformation("Session welcome on {TerminalId}", terminal.Id);
            logger.LogDebug("Connected from {Endpoint}", terminal.Id);
            // ...
        }
        catch (Exception e)
        {
            logger.LogError(e, "Session error: {Message}", e.Message);
        }
    }
}
```

## Next Steps

1. Update `TelnetServer.cs` logging configuration ✅
2. Update `appsettings.json` with logging levels
3. Gradually replace `Debug.WriteLine` and `Trace.TraceInformation` in classes
4. Inject `ILogger<T>` into classes that need logging
5. Test with different log levels to find right balance
6. Configure environment-specific settings

---

## Resources

- [Microsoft.Extensions.Logging Documentation](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging)
- [Log Levels](https://learn.microsoft.com/en-us/dotnet/api/microsoft.extensions.logging.loglevel)
- [Structured Logging](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging?tabs=command-line#log-filtering)
