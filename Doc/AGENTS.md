# 🤖 Sezam Agent Guidelines (AGENTS.md)

Primary guide for AI agents working in the Sezam BBS codebase. Follow these guidelines for maximum productivity and minimal context switching.

## 🚀 Workflow & Best Practices

1. **Documentation Location**: All new `.md` docs go in `/Doc/` — never in the root directory.
2. **Link, don't embed**: Reference existing docs/patterns rather than copying large blocks of code.
3. **Code Review Focus**: Prioritize adherence to established patterns over minor style issues unless a critical bug is found.

## 🏛️ Architecture Overview

**Sezam** is a .NET 10 BBS (bulletin board system) recreation with multi-interface support (Telnet, Web, Console). Uses a **session-based architecture** with thread-per-session execution and reflection-driven command processing.

### Core Layers

| Project | Role |
|---------|------|
| `Sezam.Data` | EF Core context (`SezamDbContext`), per-session scoping, multi-tenant isolation |
| `Sezam.Commands` | `CommandSet` hierarchy; commands via reflection on `[Command]`-decorated methods |
| `Sezam.Console` | Session lifecycle, `ITerminal` abstraction, thread management |
| `Sezam.Telnet` | Entry point executable; initializes `Server`, loads configuration |
| `Sezam.Web` | ASP.NET Core Razor Pages; reuses `SezamDbContext` and `Store` config |

### Data Flow

```
User Connection → Server/Session creates ITerminal
→ Session.Run() calls InputAndExecCmd() loop
→ CommandLine.GetToken() parses input
→ CommandSet.ExecuteCommand() via reflection
→ Commands may invoke nested CommandSets (Mail, Chat, Conference)
→ Changes persisted via session-scoped DbContext
```

### Key Entry Points

- **Telnet**: [Telnet/Sezam.Telnet.csproj](Telnet/Sezam.Telnet.csproj)
- **Web**: [Web/Program.cs](Web/Program.cs)
- **Commands**: [Console/Commands/CommandSet.cs](Console/Commands/CommandSet.cs), [Commands/Root.cs](Commands/Root.cs)
- **Session**: [Console/Session.cs](Console/Session.cs), [Console/Server.cs](Console/Server.cs)
- **Messaging**: [Data/Store.cs](Data/Store.cs), [Data/Messaging/MessageBroadcaster.cs](Data/Messaging/MessageBroadcaster.cs)
- **Session Registry**: [Data/Messaging/DistributedSessionRegistry.cs](Data/Messaging/DistributedSessionRegistry.cs)

## 💡 Critical Coding Patterns

### Command Execution

- Inherit from `CommandSet`; public `void`/return methods become commands.
- Decorate with `[Command]` for optional display name/aliases.
- Nested command sets: `GetCommandSet()` recursively resolves matching `CommandSet` methods.
- Command parsing is case-insensitive; tokens from `CommandLine`.

### Terminal I/O Abstraction

- Implement `ITerminal` (see `ConsoleTerminal`, `TelnetTerminal`).
- Session owns terminal; errors may throw `TerminalException` for client disconnect/interrupt.
- `terminal.Line()` for output, `terminal.PromptEdit()` for input, `terminal.PromptSelection()` for menus.
- **Use wait-based signaling for input; avoid polling loops and delay-based waits.**

### Database & Sessions

- `SezamDbContext` is **per-session scoped** via `Context.UserId` set in `Session.GetDbContext()`.
- Query filters in `OnModelCreating()` auto-scope `UserConf` and `UserTopic` to the current user.
- Configuration priority: **Environment Variables** → `appsettings.json` → Defaults.

### Configuration Injection

- `IConfigurationRoot` passed to `Server`/`Startup` constructors.
- Both resolve via `Environment.GetEnvironmentVariable()` first.
- Use `Store.GetOptionsBuilder()` for DbContext options.

### Error Handling

- `ErrorHandling.Handle(e)` logs exceptions; sessions continue unless terminal disconnects.
- `NotImplementedException` for planned features — safe for iteration in session loop.
- Terminal-level errors throw `TerminalException`; connection errors bubble to session cleanup.

## 🛠️ Build & Testing Commands

| Action | Command |
|--------|---------|
| Build all | `dotnet build Sezam.sln` |
| Run watch mode | `dotnet watch run -p Telnet/Sezam.Telnet.csproj` |
| Publish release | `dotnet publish -c Release Telnet/Sezam.Telnet.csproj` |
| Unit tests | `dotnet test Sezam.sln` |

## 📚 Documentation Index

All docs live in `/Doc/`. Reference by topic:

| Category | Prefix | Examples |
|----------|--------|----------|
| Architecture | `ARCHITECTURE_*.md` | `ARCHITECTURE_DIAGRAMS_FINAL.md` |
| Data/Store | `DATA_*.md` | `DATA_STORE_COMPLETE_REFERENCE.md` |
| Sessions | `SESSION_*.md`, `DISTRIBUTED_SESSIONS*.md` | `DISTRIBUTED_SESSIONS_QUICKSTART.md` |
| Redis | `REDIS_*.md` | `REDIS_CONFIGURATION_RESEARCH.md` |
| Logging | `LOGGING_*.md` | `LOGGING_SETUP_GUIDE.md` |
| Localization | `LOCALIZATION_*.md` | `LOCALIZATION_COMPLETE.md` |
| Robustness | `ROBUSTNESS_*.md` | `ROBUSTNESS_RELIABILITY_GUIDE.md` |
| Optimization | `OPTIMIZATION_*.md` | `OPTIMIZATION_SUMMARY.md` |
| Status | `STATUS.md`, `FINAL_SUMMARY.md` | Consolidation summaries |

See [DOCUMENTATION_COMPLETE_INDEX.md](DOCUMENTATION_COMPLETE_INDEX.md) for the full index.

## 🔄 Common Tasks

| Task | Approach |
|------|----------|
| Add new command | Create method in `CommandSet` subclass, decorate with `[Command]` |
| Add new entity | Create class in `Docs/` and `EF/`, update `SezamDbContext` DbSets |
| Add new terminal type | Implement `ITerminal`, use in `Session`/`Server` constructor |
| Debug session state | Access via `CommandSet.session`; inspect `session.User` or `session.Db` |

## 🔧 Project Conventions

- **Naming**: Regional resources (`.resx` files) for localization via `strings` class.
- **Entity mirror**: `EF/` folder mirrors `Docs/` folder (D.O and D.M patterns).
- **Sessions**: Stored in `Data.Store.Sessions` (ConcurrentDictionary); accessed globally.
- **Build output**: `/bin/net10.0/` (shared by all projects).
- **Global config** lives in `Data.Store` (singleton pattern):
  ```csharp
  Store.DbConnectionString           // Database
  Store.RedisConnectionString        // Redis host:port
  Store.RedisEnabled                 // Is Redis active?
  Store.Sessions                     // All active local sessions
  Store.SendToUser(...)              // Messaging API
  Store.SendToChat(...)
  Store.LocalBroadcast(...)
  Store.GlobalBroadcast(...)
  ```

## 📁 File Organization Rules

```
Root directory  → ONLY README.md (keep clean)
/Doc/           → ALL .md documentation (no exceptions)
  ARCHITECTURE_*.md  → System design & architecture
  REDIS_*.md         → Redis/configuration
  DATA_*.md          → Database/data model
  SESSION_*.md       → Session management
  ROBUSTNESS_*.md    → Error handling & resilience
  OPTIMIZATION_*.md  → Performance
```

## 🤖 Available Agents

Agents for specialized exploration tasks:

| Agent | Purpose | File |
|-------|---------|------|
| `codebase-explorer` | General codebase exploration | `.github/agents/codebase-explorer.agent.md` |
| `database-explorer` | Entities, migrations, DbContext | `.github/agents/database-explorer.agent.md` |
| `messaging-tracer` | Message flow, broadcasts, Redis | `.github/agents/messaging-tracer.agent.md` |
| `terminal-explorer` | I/O, input/output, terminal I/O | `.github/agents/terminal-explorer.agent.md` |

---

## ⚠️ Pitfalls & Tips

- **`/Doc/` only**: Never create `.md` files directly in the root — they belong in `/Doc/`.
- **Link over embed**: Reference existing docs via Markdown links; don't copy large blocks into new files.
- **Test after changes**: Always run `dotnet build Sezam.sln` to verify changes don't break the build.
- **Target framework**: All projects target `net10.0` via `Directory.Build.props`.
- **Redis channel naming**: Use `RedisChannel.Literal()` (not implicit string conversion) for channel names.
- **Session scope**: `SezamDbContext` is per-session — don't expect cross-session queries to work without explicit joins.

