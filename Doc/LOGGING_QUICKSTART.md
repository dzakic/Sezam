# Logging Implementation - Quick Start

## What Changed

### TelnetServer.cs
✅ Removed old `Trace.Listeners` approach
✅ Added structured logging with `Microsoft.Extensions.Logging`
✅ Configured console provider with colors and timestamps
✅ Set minimum level to Debug for development

### appsettings.json
✅ Added `Logging` section with LogLevel hierarchy
✅ Configured console options (scopes, timestamps)
✅ Set appropriate levels for different namespaces

## Current Configuration

```json
"Logging": {
  "LogLevel": {
    "Default": "Information",      // Most things
    "Microsoft": "Warning",         // Framework only important messages
    "Sezam": "Information"          // Your app messages
  },
  "Console": {
    "IncludeScopes": true,
    "TimestampFormat": "HH:mm:ss "
  }
}
```

## Next Steps: Migrate Your Code

### 1. Server.cs / TelnetHostedService
```csharp
public class TelnetHostedService : IHostedService
{
    private readonly ILogger<TelnetHostedService> logger;
    
    public TelnetHostedService(ILogger<TelnetHostedService> logger)
    {
        this.logger = logger;
    }
    
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        logger.LogInformation("Telnet server starting on port 2023");
        logger.LogDebug("Configuration loaded: {Config}", configDetails);
        // ...
    }
}
```

### 2. Session.cs
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
            logger.LogInformation("Session started");
            await WelcomeAndLogin();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Session error");
        }
    }
}
```

### 3. Command Classes
```csharp
public class MyCommand : CommandSet
{
    private readonly ILogger<MyCommand> logger;
    
    public MyCommand(Session session, ILogger<MyCommand> logger) : base(session)
    {
        this.logger = logger;
    }
    
    [Command("mycommand")]
    public async Task Execute()
    {
        logger.LogInformation("Executing mycommand for user {Username}", 
            session.Username);
        logger.LogDebug("Command details: {Details}", details);
    }
}
```

## Log Levels Reference

| Level | Usage | Color |
|-------|-------|-------|
| Trace | Most detailed diagnostic info | - |
| Debug | Detailed debugging info | Blue 🔵 |
| Information | General informational messages | Green 🟢 |
| Warning | Warning messages | Yellow 🟡 |
| Error | Error messages | Red 🔴 |
| Critical | Critical failures | Red 🔴 |

## How to Change Log Level at Runtime

### For Development (Debug everything)
```json
"Logging": {
  "LogLevel": {
    "Default": "Debug",
    "Sezam": "Debug"
  }
}
```

### For Production (Information and above)
```json
"Logging": {
  "LogLevel": {
    "Default": "Information",
    "Sezam": "Information"
  }
}
```

### For Troubleshooting Specific Component
```json
"Logging": {
  "LogLevel": {
    "Default": "Information",
    "Sezam.Commands": "Debug",     // Debug this
    "Sezam.Console": "Information" // Keep this normal
  }
}
```

## Example Output

With the new setup, you'll see nicely formatted, colored output:

```
info: Sezam.TelnetHostedService[0]
      Telnet server starting on port 2023
dbug: Sezam.TelnetHostedService[0]
      Configuration loaded: redis=localhost:6379
info: Sezam.Console.Session[0]
      Session started from 192.168.1.100
info: Sezam.Console.Session[0]
      User logged in: alice
dbug: Sezam.Commands.Mail[0]
      Processing Mail command
info: Sezam.Commands.Mail[0]
      Mail sent successfully
```

## Benefits

✅ Colored output makes logs easier to read
✅ Hierarchy (Trace, Debug, Information, Warning, Error) for different verbosity levels
✅ Runtime filtering via appsettings.json - no code changes needed
✅ Structured logging with scopes for context
✅ Integration with .NET framework logging
✅ Performance-efficient
✅ Easy to add file logging, event logs, etc. later

## Notes

- Build is successful ✅
- Old `Trace` and `Debug.WriteLine` approach can be gradually replaced
- Start by adding logging to new code
- Migrate existing code at your own pace
- Configuration is now in appsettings.json for easy runtime adjustment

---

See `LOGGING_SETUP_GUIDE.md` for complete details and examples.
