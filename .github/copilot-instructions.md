# Sezam Copilot Instructions

## Architecture Overview

**Sezam** is a .NET 10 BBS (bulletin board system) recreation with multi-interface support (Telnet, Web, Console). The system uses a **session-based architecture** with thread-per-session execution and reflection-driven command processing.

### Core Layers

- **Sezam.Data**: EF Core context (`SezamDbContext`) with per-session scoping and query filters for multi-tenant isolation
- **Sezam.Commands**: Command hierarchy via `CommandSet` base class; commands invoked via reflection on public methods decorated with `[Command]`
- **Sezam.Console**: Session lifecycle (`Session` class), terminal abstraction (`ITerminal`), and thread management
- **Sezam.Telnet**: Entry point executable; initializes `Server` (Telnet listener), loads configuration, hosts console/Telnet sessions
- **Sezam.Web**: ASP.NET Core Razor Pages interface; reuses `SezamDbContext` and `Store` configuration

### Data Flow

```
User Connection → Server/Session creates ITerminal (Console/Telnet) 
→ Session.Run() calls InputAndExecCmd() loop
→ CommandLine.GetToken() parses input
→ CommandSet.ExecuteCommand() via reflection finds matching method
→ Commands may invoke nested CommandSets (e.g., Mail, Chat, Conference)
→ Changes persisted via session-scoped DbContext
```

## Key Patterns

### Command Execution
- Inherit from `CommandSet`; public void/return methods become commands
- Use `[Command]` attribute on methods for optional display name/aliases
- Nested command sets: `GetCommandSet()` recursively looks for CommandSet methods in current class
- Command parsing is case-insensitive; tokens from `CommandLine`

**Example:**
```csharp
[Command("")]  // Root command set
public class Root : CommandSet {
    public Conference Conference() => null;
    
    [Command(Aliases = "..")]
    public void GoBack() { /* */ }
}
```

### Terminal Abstraction
- Implement `ITerminal` (see `ConsoleTerminal`, `TelnetTerminal`) for I/O strategy
- Session owns terminal; errors may throw `TerminalException` to signal client disconnect or interrupt
- Use `terminal.Line()` for output, `terminal.PromptEdit()` for input, `terminal.PromptSelection()` for menu prompts

### Database & Sessions
- `SezamDbContext` is **per-session scoped** via `Context.UserId` property set in `Session.GetDbContext()`
- Query filters in `OnModelCreating()` automatically scope `UserConf` and `UserTopic` to current user
- Configuration read from environment variables first, then `appsettings.json`: `ServerName`, `Password`, connection string
- Users authenticated per-session; multi-user isolation is automatic via context filters

### Session Management
- `Session` runs on a dedicated thread (`Session.thread`)
- `Server.sessions` (thread-safe list) tracks active `ISession` instances
- Session catches and logs exceptions; continues on `ArgumentException`, `NotImplementedException`
- Terminal disconnection raises `TerminalException(ClientDisconnected)` to cleanly exit

## Build & Deployment

### Local Development

```bash
# Build Telnet executable
dotnet build Sezam.Telnet/Sezam.Telnet.csproj

# Run watch mode (auto-rebuild)
dotnet watch run -p Sezam.Telnet/Sezam.Telnet.csproj

# Publish for deployment
dotnet publish -c Release Sezam.Telnet/Sezam.Telnet.csproj
```

### Docker & Kubernetes
- `Dockerfile`: Multi-stage build; runs `Sezam.Web` (ASP.NET Core)
- `deployment.yaml`: k8s deployment for Web tier; 2 replicas by default
- Environment vars for config: `ServerName`, `Password`, EF connection strings

### Output & Configuration
- Built binaries: `/bin/net9.0/` (shared by all projects)
- `appsettings.json` copied to output directory; override via environment variables at runtime
- Web and Telnet use same `Store` config; both read `ServerName` and `Password` on startup

## Project Conventions

### Naming & Structure
- Classes use regional resources (`.resx` files) for localization via `strings` class
- Database entities: `EF/` folder mirrors `Docs/` folder (separate D.O and D.M patterns)
- Sessions stored in `Data.Store.Sessions` (thread-safe list); accessed globally

### Error Handling
- `ErrorHandling.Handle(e)` logs exceptions; sessions continue unless terminal disconnects
- `NotImplementedException` for planned features; safe for iteration in session loop
- Terminal-level errors throw `TerminalException`; connection errors bubble to session cleanup

### Configuration Injection
- `IConfigurationRoot` passed to `Server`/`Startup` constructors
- Both resolve via `Environment.GetEnvironmentVariable()` first (deployment flexibility)
- Connection strings defined in EF model; use `Store.GetOptionsBuilder()` for DbContext options

## Common Tasks

- **Add new command**: Create method in desired `CommandSet` subclass, decorate with `[Command]` if needed
- **Add new database entity**: Create class in `Docs/` and `EF/`, update `SezamDbContext` DbSets
- **Add new terminal type**: Implement `ITerminal`, use in `Session` constructor or `Server`
- **Debug session state**: Access current session via `CommandSet.session` property; inspect `session.User` or `session.Db`

## References

- **Entry points**: [Telnet/Sezam.Telnet.csproj](Telnet/Sezam.Telnet.csproj), [Web/Program.cs](Web/Program.cs)
- **Command dispatch**: [Console/Commands/CommandSet.cs](Console/Commands/CommandSet.cs), [Commands/Root.cs](Commands/Root.cs)
- **Session lifecycle**: [Console/Session.cs](Console/Session.cs), [Console/Server.cs](Console/Server.cs)
- **Database model**: [Data/Store.cs](Data/Store.cs), [Data/EF/](Data/EF/)
- **Terminal interface**: [Console/Terminal/Terminal.cs](Console/Terminal/Terminal.cs), [Console/Terminal/TelnetTerminal.cs](Console/Terminal/TelnetTerminal.cs)
