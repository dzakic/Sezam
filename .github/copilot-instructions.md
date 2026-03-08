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

## Documentation & File Organization Conventions

### Root Folder
- **ONLY** `README.md` in root directory
- All other `.md` files go in `/Doc`
- Root must stay clean and organized
- Exception: Only standard project files (LICENSE, .gitignore, etc.)

### Documentation Files (/Doc folder - CRITICAL RULE)
- **ALL .md documentation files go in `/Doc`** - NO EXCEPTIONS
- Includes: Architecture, research, reference, guides, implementations, status
- Naming: Use descriptive SNAKE_CASE or TITLE_CASE (e.g., `REDIS_CONFIGURATION_RESEARCH.md`, `DATA_STORE_COMPLETE_REFERENCE.md`)
- Structure: Organize by topic (prefix with feature/topic area)
- Categories:
  - `ARCHITECTURE_*.md` - System design and architecture
  - `REDIS_*.md` - Redis/configuration related
  - `DATA_*.md` - Database/data model docs
  - `SESSION_*.md` - Session management
  - `OPTIMIZATION_*.md` - Performance and optimization
  - `ROBUSTNESS_*.md` - Error handling and resilience
  - Status files: `STATUS.md`, `FINAL_SUMMARY.md`

### Operational Documentation (During Sessions)
- Session-specific documents created during work start in `/Doc`
- Do NOT create ad-hoc summary files in root
- Consolidate findings into architectural/reference docs
- Delete temporary/operational docs after session review

### Persistent Documentation (Evergreen)
Keep in `/Doc` - These are referenced by future sessions:
- Architecture diagrams and overviews
- Complete API references
- Configuration patterns and guides
- Database schema documentation
- Performance optimization strategies
- Robustness and error handling patterns
- Architectural decisions and rationale

### Session Guidelines
When working:
1. Create all new `.md` files in `/Doc` - not in root
2. Consolidate findings into existing architectural docs
3. Don't create ad-hoc session summary files in root
4. Update existing docs rather than creating new ones
5. Keep root folder clean - only README.md

## Configuration Management (Critical Pattern)

### Smart Configuration in Data.Store
```csharp
// ALL global configuration and services go in Data.Store
Store.ServerName              // Database host
Store.DbName                  // Database name (default: "sezam")
Store.Password                // Database password
Store.RedisConnectionString   // Redis host:port
Store.RedisEnabled            // Is Redis configured?
Store.MessageBroadcaster      // Global broadcaster singleton
Store.Sessions                // All active sessions (thread-safe)
```

### Configuration Rules
- **Priority**: Environment variables → Config file → Defaults
- **Host inference**: `DB_HOST` and `REDIS_HOST` auto-inferred to full connection strings
- **Graceful disabling**: Features (Redis) auto-disable if not configured
- **Singletons**: Global services stored in `Data.Store`; accessible from anywhere

### Redis Configuration
- Centralized in `Data.Store.RedisConnectionString`
- Check availability via `Data.Store.RedisEnabled`
- Use `RedisChannel.Literal()` for channel names (NOT implicit string conversion)
- Channels: `"sezam:broadcast"` (messages), `"sezam:sessions"` (session events)

## Build & Code Quality Standards

- Always verify build is successful: `dotnet build`
- Fix deprecation warnings (e.g., `RedisChannel.Literal()`)
- No breaking changes without careful consideration
- Maintain 100% backward compatibility
- Document all changes to public APIs

## Logging Standards

- Use `Microsoft.Extensions.Logging` with `ILogger<T>` injection
- Never use old `System.Diagnostics.Trace` or `Debug.WriteLine`
- Configure log levels in appsettings.json (not in code)
- Log levels: Trace → Debug → Information → Warning → Error → Critical
- Structured logging: use named parameters for context
- Example: `logger.LogInformation("User {Username} logged in", username)`
- Scopes for context: `using (logger.BeginScope("UserId: {UserId}", userId))`
- Configuration: See `Doc/LOGGING_SETUP_GUIDE.md` for complete patterns

## Session Guidelines

When starting work:
1. Read this file for conventions
2. Check `/Doc` for relevant documentation
3. Understand architecture via existing docs
4. Create research/planning docs in `/Doc` before implementation
5. Update this file with new conventions as they emerge
6. Keep `/Doc` organized; root directory clean
7. Verify final build is successful and warning-free
