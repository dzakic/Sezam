# 🤖 Sezam Agent Guidelines (AGENTS.md)

This document serves as the primary guide for AI coding agents working within the Sezam BBS recreation codebase. Follow these guidelines for maximum productivity and minimal context switching.

## 🚀 Workflow & Best Practices
1.  **Documentation Location**: All new architectural decisions, research findings, or guides **must** be created in the `/Doc` folder (e.g., `DATA_STORE_COMPLETE_REFERENCE.md`). Do not create ad-hoc summary files in the root directory.
2.  **Principle**: Always "Link, don't embed." Reference existing documentation and patterns rather than copying large blocks of code or text into new implementation files.
3.  **Code Review Focus**: When reviewing code, prioritize adherence to established patterns over minor style issues unless a critical bug is found.

## 🏛️ Sezam Architecture Overview (Reference: [DATA_STORE_COMPLETE_REFERENCE.md](DATA_STORE_COMPLETE_REFERENCE.md))
*   **Core Layers**: The system operates across distinct layers: `Sezam.Data` (EF Core), `Sezam.Commands`, `Sezam.Console`, and `Sezam.Web`.
*   **Execution Model**: It utilizes a **session-based architecture** with thread-per-session execution, managed by the `Session` class.

## 💡 Critical Coding Patterns to Follow
### Command Execution (Pattern: [ARCHITECTURE_DIAGRAMS_FINAL.md](ARCHITECTURE_DIAGRAMS_FINAL.md))
*   Commands are implemented in classes inheriting from `CommandSet`.
*   Methods decorated with `[Command]` become accessible commands.
*   Nested command sets (`GetCommandSet()`) allow for deep, structured command trees (e.g., Mail -> Send).

### Data Scoping & Context (Pattern: [DISTRIBUTED_SESSIONS.md](DISTRIBUTED_SESSIONS.md))
*   **Per-Session Scope**: `SezamDbContext` is strictly scoped to the current session via `Context.UserId`. This ensures multi-tenant isolation automatically for entities like `UserConf` and `UserTopic`.
*   **Configuration Priority**: Global configuration (Redis, DB connection strings) follows: **Environment Variables** $\rightarrow$ `appsettings.json` $\rightarrow$ Defaults.

### Terminal I/O Abstraction (Pattern: [LOGGING_SETUP_GUIDE.md](LOGGING_SETUP_GUIDE.md))
*   All input/output must flow through the `ITerminal` interface implementation (`ConsoleTerminal`, `TelnetTerminal`).
*   **Crucial**: Use wait-based signaling for console input, avoiding polling loops.

## 🛠️ Build & Testing Commands
*   **Build All**: `dotnet build Sezam.sln` (Always run first).
*   **Run Watch Mode**: `dotnet watch run -p Telnet/Sezam.Telnet.csproj` (For development cycle).
*   **Unit Tests**: `dotnet test Sezam.sln`.

## 📚 Documentation Indexing
*   Use the `/Doc` folder for all persistent documentation.
*   Refer to existing guides:
    *   [Redis Setup](REDIS_QUICKSTART.md)
    *   [Logging Standards](LOGGING_SETUP_GUIDE.md)
    *   [Messaging API code](../Data/Store.cs) and relevant Redis/session docs in this folder.

