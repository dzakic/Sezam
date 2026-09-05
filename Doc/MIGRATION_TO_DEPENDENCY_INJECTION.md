# Migration to Dependency Injection (Planned)

> Status: **Deferred.** This documents a future refactor. The current
> implementation uses a static composition root (`Data/Store`). Do NOT begin
> the DI migration until it is explicitly started. See "Why defer" below.

The purpose of this document is to capture the *current architecture*, the
*interim test seam* that decouples tests from production, and a concrete plan
for eventually migrating to real dependency injection. It is written so that a
future session can start cleanly without rediscovering these facts.

---

## 1. Why defer (as of 2026-09-05)

The immediate priority was un-coupling the test/InMemory DB logic from
production code so it could be checked in. That is done. The deeper work —
replacing the global `Store` singleton with a real DI container — is a
larger, riskier change (many static call sites, web + console + legacy import
entry points) and should be its own dedicated effort, not rushed alongside
other fixes.

This doc is the plan for that effort so it can start later with full context.

---

## 2. Current architecture (the thing we are migrating away from)

### 2.1 `Data/Store.cs` — the static composition root

`Store` is a `static` class that acts as the application's composition root.
It holds globally-singleton configuration and a couple of singletons. It is
**not** a real DI container; it is a set of mutable static fields that every
project reaches into directly.

Held in `Store` today:

| Field | Purpose |
|-------|---------|
| `DbConnectionString` | Resolved connection string for the EF provider (MySQL in prod) |
| `RedisConnectionString` | Optional StackExchange.Redis connection |
| `LoggerFactory` | Global `ILoggerFactory`; `logger` derived from it |
| `MessageBroadcaster` | Global singleton used to distribute session messages |
| `Sessions` (`ConcurrentDictionary<Guid, ISession>`) | Live session registry |

There is **no DI container** anywhere. The web project calls
`AddDbContext<SezamDbContext>(...)`, but that is only EF Core *service
registration* — it still resolves options from `Store.GetOptionsBuilder()`.
That registration is registration, not injection of `Store`'s dependencies.

### 2.2 DbContext wiring

`SezamDbContext` (a per-user-scoped `DbContext` with a
`UserId`-based `[HasQueryFilter]`) is constructed in exactly two ways:

1. **`Store.GetNewContext()`** — used by the Console/Legacy code paths.
   Builds a `DbContextOptionsBuilder`, runs it through `GetOptionsBuilder()`,
   and does `new SezamDbContext(options.Options)`.
2. **`Store.GetOptionsBuilder(options)`** — used by the Web project via
   `AddDbContext`, and by the EF design-time factory
   (`SezamDbContextFactory` / `dotnet-ef`).

### 2.3 `GetOptionsBuilder` — the production/test branch

\`\`\`csharp
public static Func<DbContextOptionsBuilder, DbContextOptionsBuilder>? OptionsFactory { get; set; }

public static DbContextOptionsBuilder GetOptionsBuilder(DbContextOptionsBuilder builder)
{
    if (LoggerFactory != null)
        builder.UseLoggerFactory(LoggerFactory);

    if (OptionsFactory is not null)
        return OptionsFactory(builder);

    return builder
        .UseMySQL(DbConnectionString)
        .EnableSensitiveDataLogging()
        .UseLazyLoadingProxies();
}
\`\`\`

- In **production**, `OptionsFactory` is `null`, so the production branch wires
  up MySQL + sensitive data logging + lazy-loading proxies.
- In **tests**, `Tests/Sezam.Tests/InMemoryDb.Enable()` sets
  `OptionsFactory` to substitute `UseInMemoryDatabase(...)`.

This is the interim seam. See §4.

### 2.4 Call sites (everything that reaches into `Store`)

| File | Line | What |
|------|------|------|
| `Data/Store.cs` | 127, 131, 133 | `SezamDbContextFactory` (design-time) |
| `Data/Store.cs` | 193–214 | `OptionsFactory` property + `GetOptionsBuilder` + `GetNewContext` |
| `Console/Server.cs` | 31 | `Store.ConfigureFrom(configuration)` at startup |
| `Console/Session.cs` | ~29 | `lazyDb = new Lazy<SezamDbContext>(() => Store.GetNewContext(), ...)` |
| `Web/Startup.cs` | 22 | `Store.ConfigureFrom(configuration)` in constructor |
| `Web/Startup.cs` | ~31 | `.AddDbContext<SezamDbContext>(options => Data.Store.GetOptionsBuilder(options))` |
| `Legacy/Import/Program.cs` | 49 | `Store.ConfigureFrom(configuration)` at startup |
| `Legacy/Import/Program.cs` | 69 | `Store.GetNewContext()` for reset/migrate |
| `Legacy/Import/ZBB/Importer.cs` | 25, 105 | `Store.GetNewContext()` inside import methods |

Other references (`Store.RedisEnabled`, `Store.MessageBroadcaster`,
`Store.LoggerFactory`, `Store.Sessions`, `Store.logger`) exist across the code
base and must be migrated as part of the DI effort.

---

## 3. The interim test seam: `Data/Store.OptionsFactory`

This seam was introduced so the **production code no longer references tests**.

- Previously, `GetOptionsBuilder()` contained a `SEZAM_TEST_DB` override that
  switched to the InMemory provider when a test env var was set. That meant the
  production assembly had to know about a test-only database — a coupling we
  want to remove.
- Now: `Data/Store.cs` never mentions the InMemory provider. `Tests/Sezam.Tests/InMemoryDb.cs`
  holds the test substitution and flips `Store.OptionsFactory` on in
  `[SetUp]` / off in `[TearDown]`.

Consequence for the migration: once we have a real DI container, the test
substitution should move **entirely into the test project** (see §6.3) and
`Store.OptionsFactory` can be removed. The seam is a temporary bridge, not the
final design.

> Note on test ordering: the test project runs fixtures **sequentially** (no
> `[Parallelizable]` attribute), so a single static `OptionsFactory` slot is
> safe from cross-fixture races. If tests are ever made parallel, this static
> slot would need to become per-context.

---

## 4. Migration plan (for when we start)

### 4.1 Goals

- Introduce a real DI container (e.g. `Microsoft.Extensions.Hosting` /
  `WebApplicationFactory`-style `Host`) as the single composition root.
- Replace `Store`'s static fields with registered services:
  - `SezamDbContext` → registered per-scope (scoped lifetime), options built
    from resolved configuration, **not** from a static field.
  - `MessageBroadcaster` → scoped/singleton with explicit lifecycle.
  - Logging → resolve `ILogger<T>` from constructor injection; drop the global
    `Store.LoggerFactory` setter.
  - Config → inject `IConfiguration` where needed instead of `Store.ConfigureFrom`.
- Remove the `Store` static composition root (or shrink it to nothing).

### 4.2 Entry points to migrate

| Entry point | Current pattern | DI target |
|-------------|-----------------|-----------|
| **Web** (`Web/Startup.cs`) | `AddDbContext(... GetOptionsBuilder(...))` + `ConfigureFrom` | Build a `Host`/`WebApplication`; register `SezamDbContext` scoped; resolve `MessageBroadcaster` |
| **Console** (`Console/Server.cs`, `Console/Session.cs`) | `ConfigureFrom` + `new Lazy<SezamDbContext>(() => Store.GetNewContext())` | Host the console app; resolve `SezamDbContext` per session via scoped provider |
| **Legacy import** (`Legacy/Import/Program.cs`, `Legacy/Import/ZBB/Importer.cs`) | `ConfigureFrom` + `Store.GetNewContext()` | Register a scoped provider and resolve contexts; keep reset/migrate behavior |

### 4.3 Ordering of changes

1. Establish a host/container and resolve `IConfiguration` first.
2. Register `SezamDbContext` scoped with options sourced from configuration.
3. Migrate the Web entry point (highest surface area, `AddDbContext`).
4. Migrate `Console/Session.cs` — replace `Lazy<SezamDbContext>` with an
   injected `Func<SezamDbContext>` scoped provider.
5. Migrate the Legacy import entry point(s).
6. Replace `Store.MessageBroadcaster` / `logger` / `loggerFactory` usages with
   injected services.
7. Delete `Store.GetNewContext()` / `GetOptionsBuilder()` / `OptionsFactory`.
8. Remove the test seam (§6.3) and the `OptionsFactory` property.

### 4.4 Risks

- **Static coupling is deep.** Many files reference `Store.*`. Audit with the
  call sites in §2.4 before deleting anything.
- **`SezamDbContext` is multi-tenant** (`UserId` query filter). The DI target
  must still set `UserId` per scope/request, not globally.
- **Web `AddDbContext` currently only does EF registration**, not full
  injection. This is a genuine step toward DI but not DI by itself — the plan
  must go further (§5).

---

## 5. Scope note: `AddDbContext` is not DI

`Web/Startup.cs` calls `AddDbContext<SezamDbContext>(...)`, which only
**registers the DbContext with the container and wires its options**. The app
still reads options from `Store.GetOptionsBuilder()` and still reaches into
`Store` for config, logging, and the broadcaster. So the web project is *part
way* toward DI but has **not** eliminated the static root. The plan in §4.1–4.3
is what actually completes the migration.

---

## 6. Test-concern migration (must happen)

### 6.1 Move InMemory substitution fully into the test project

Currently the substitution lives behind `Store.OptionsFactory` (a static slot
in the production assembly). Replace it with:

- A **scoped DbContext registration** in the test host wired to
  `UseInMemoryDatabase(...)`, OR
- A test-only factory that produces `SezamDbContext` instances bound to the
  in-memory database, injected where `Session.Db` / `GetNewContext()` is used.

### 6.2 Eliminate the production test hook

Delete `Store.OptionsFactory`, `Store.GetOptionsBuilder()` (and its test
branch), and `Tests/Sezam.Tests/InMemoryDb.cs` once tests use the test-scoped
registration. The production assembly should never again reference the
InMemory provider.

### 6.3 Static test state caveat

Because `OptionsFactory` is static, test fixtures must reset it between runs
(both `InMemoryDb.Enable()` in `[SetUp]` and `Disable()` in `[TearDown]`).
After DI, per-scope registration removes this shared-state fragility entirely