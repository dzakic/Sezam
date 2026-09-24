# 📋 CODE REVIEW — Findings & TODOs

**Reviewed:** 2026-08-07
**Stack:** .NET 10 / C# 14
**Scope:** Full solution (Commands, Console, Data, Web, Tests) — representative cross-section.
**Overall:** Modern C# is already used well in many places. Review below prioritizes the highest-impact changes first.

---

## ⭐ P1 — High impact

### 1. Nullable Reference Types — project-wide
- **Problem:** `Nullable` is enabled *per-file* with `#nullable enable` (only ~5 source files). Migrations actively `#nullable disable`. Most of the codebase runs with NRT off, forcing manual `?` markers everywhere (`session.User?.Password`, `s.NodeId?[..8]`).
- **Fix:** Enable project-wide in `Directory.Build.props`:
  ```xml
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>disable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
  ```
- **Why:** Compiles away a whole class of manual `?` hacks and forces nullability correctness.
- **Rollout:** Per-project, not all at once (avoids giant merge).

### 2. Culture-aware string formatting (real localization bug)
- **Problem:** `LocalizationHelper.GetStr(args)` uses `string.Format(format, args)` — formats in the *current thread* culture, not the user's configured culture. All the localization setup is defeated for numbers/dates.
- **Fix:** Pass the session culture to `string.Format` the same way `GetString` does. Also flatten `Session.cs:473` (`logger.LogInformation("{Message}", string.Format(Message, args))`) — it formats eagerly (defeating lazy logging) and loses culture.

### 3. Bare empty `catch { }` in production code
- **Problem:** ~15 bare `catch { }` with nothing inside — `Set.cs:72,98`, `Session.cs:129,415`, `TelnetTerminal.cs:225-229`, `Server.cs:183,201,210`. CA1031 discourages swallowing silently.
- **Fix:** In `Set.cs` (~72/98) catch the *specific* exceptions instead (`TimeZoneNotFoundException`, `ZoneNotFoundException`) so you only hide what you intend. Tests are fine to leave alone.

---

## 🟡 P2 — Moderate

### 4. Minimal hosting in Web
- **Problem:** `Web/Program.cs` still uses legacy `ConfigureWebHostDefaults(w => w.UseStartup<Startup>())`.
- **Fix:** Use minimal hosting (keep Razor Pages intact):
  ```csharp
  var builder = WebApplication.CreateBuilder(args);
  // configure logging/config inline
  var app = builder.Build();
  app.MapRazorPages();
  app.Run();
  ```
- **Scope:** Moderate refactor — config/logging/`KeyPerFile` secret handling moves into `Program.cs`. Razor Pages `Pages/` still work; only `Startup` wiring changes.

### 5. `ConfigureAwait(false)` missing
- **Problem:** `Session.Run`, `Store` messaging, and other hot async paths `await` without `ConfigureAwait(false)`, holding the current `SynchronizationContext`.
- **Fix:** Add `ConfigureAwait(false)` to library-style awaits on hot paths (analyzer fix IDE0033 auto-adds these).

---

## 🟢 P3 — Quick polish

### 6. Collection expressions
- `Set.cs:13` still uses `new[] { "Europe/Belgrade", … }`. You already use collection expressions elsewhere — unify to `[ "Europe/Belgrade", … ]`.

### 7. `this.` qualifiers
- `User` constructors have redundant `this.Id = Id;`. Drop the `this.`.

---

## 🧩 Structure / logic notes (informational)

- **`Role` enum `HasFlag`** — if `Role` is `[Flags]`, `(Roles & role) == role` is faster than `HasFlag` (which boxes). Minor perf; fine to leave unless hot.
- **`TimeZoneInfo` lookups repeated** in `Set.cs` and `Root.cs` — a small cache keyed on `TimeZoneId` avoids redundant resolution.
- **`CommonZones` could be `ImmutableArray<string>`** (truly static, copy-safe).
- **Pattern-matching surface is thin** — `Root.cs` `Users()` has an `if/else` cascade that's a good switch-expression candidate.

---

## ✅ Review Checklist

- [ ] P1 — Enable Nullable project-wide (per-project rollout)
- [ ] P1 — Culture-aware string formatting in `LocalizationHelper`
- [ ] P1 — Harden production bare `catch { }`s to specific exceptions
- [ ] P2 — Minimal hosting in Web
- [ ] P2 — `ConfigureAwait(false)` on hot paths
- [ ] P3 — Collection expressions (`Set.cs`)
- [ ] P3 — Remove `this.` qualifiers in `User`
