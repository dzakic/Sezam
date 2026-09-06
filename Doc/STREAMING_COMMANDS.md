# Streaming Commands

Commands that produce multi-line output previously wrote directly to the
terminal through `session.terminal.Line(...)`. This made those commands hard to
test and impossible to redirect (e.g. to a file) without a terminal.

The refactor moves command output out of the terminal by having commands
return `IAsyncEnumerable<string>` and yielding their lines one at a time. The
stream is produced by the command, consumed by a small helper, and the helper
decides where the lines go (terminal, file, or test). See the original plan at
[`streaming-command-refactoring.md`](streaming-command-refactoring.md); this doc
records the **decisions actually made**, which diverge from that plan in several
important ways.

## Why streaming (and why `IAsyncEnumerable`, not `Task<IEnumerable<string>>`)

Three requirements drove the return type:

1. **Decoupling** — the command must not hold a reference to the terminal, so
   the same stream can go to the terminal, a file, or a captured test list.
2. **Back-pressure / laziness** — conference and message sets can be large, and
   some commands (e.g. `List` with a date range) are expensive. The stream
   should be consumed one line at a time, not buffered into a full array.
3. **Cancellation** — when the user disconnects or interrupts, a long-running
   command must be abandoned mid-stream instead of churning through its whole
   result set.

`IAsyncEnumerable<string>` satisfies all three. It is the *only* signature that
works as an async iterator (`yield return`). Note the following are **not valid
as async-iterator return types** and will fail to compile (CS1624):

- `Task<IAsyncEnumerable<string>>`
- `Task<IEnumerable<string>>`

The method body must be `async` with an **`IAsyncEnumerable<T>`** return type
directly. Commands that make no output still return `IAsyncEnumerable<string>`
and simply `yield break` (or, for pure state-change commands, return `void` or
`Task` and write to the terminal themselves — see below).

## Architecture

```
Command (async IAsyncEnumerable<string>)
        │  yields strings, cancels via CancellationToken, no terminal dependency
        ▼
AsyncEnumerableHelper.GetCommandOutput(cmdSet, name, token)
        │  reflects the command, invokes it, applies WithCancellation(...)
        ▼
Consumer:  ┌─ ExecuteStreamingAsync(...) → session.terminal.Line(line)
           ├─ ExecuteToWriterAsync(...)  → file redirect (future)
           └─ tests (List<string> capture)
```

### `AsyncEnumerableHelper` (`Console/AsyncEnumerableHelper.cs`)

A single static class with three public members:

- **`GetCommandOutput(cmdSet, name, token)`** — an async iterator that
  reflects `GetCommandMethod(name)`, then dispatches on `command.ReturnType`:
  - `void` / `Task` → invoke (and await the `Task`), `yield break`. These
    commands write to the terminal themselves and contribute nothing to the
    stream.
  - `IAsyncEnumerable<string>` → invoke, wrap in
    `WithCancellation(token)`, and re-yield each line.
  - anything else → `NotSupportedException` (fail fast, not silent).
- **`ExecuteStreamingAsync(cmdSet, name, token)`** — the terminal sink used by
  `CommandSet.InvokeCommand`; mirrors the original behaviour line-by-line.
- **`ExecuteToWriterAsync(cmdSet, name, writer, token)`** — the redirection
  sink (file, etc.). Kept in the helper so any future consumer gets
  cancellation handling for free.

### Command routing (`Console/Commands/CommandSet.cs`)

- `InvokeCommand()` (`CommandSet.cs:95`) checks
  `command.ReturnType.IsAssignableTo(typeof(IAsyncEnumerable<string>))` and
  routes streaming commands to
  `AsyncEnumerableHelper.ExecuteStreamingAsync(this, cmd, session.CancellationToken)`.
- `GetMethods()` (`CommandSet.cs:459`) now accepts the streaming return type
  alongside `void` and `Task` for help listing, catalog building, and access
  checks. The existing `Catalog` dictionary and partial-match resolution are
  unchanged, so streaming commands participate in command discovery exactly
  like their `Task` counterparts.

### `Session.CancellationToken` (`Console/Session.cs:590`)

`public CancellationToken CancellationToken => cts.Token;` is surfaced so
commands can bind their stream to the session's lifetime without taking a
`CancellationToken` parameter (which would complicate the reflection-free
`GetMethods()` signature and command invocation).

## Cancellation: stop, don't throw

The stream is **abandoned, not aborted**: when the token is cancelled,
`MoveNextAsync` returns `false` and enumeration ends cleanly. The command's own
loop honours the token and stops; no exception is thrown to the consumer.

This is implemented by `WithCancellation<T>()`
(`AsyncEnumerableHelper.cs:95`), which wraps a source stream. Between items it
asks the source to stop; the consumer simply sees the stream end. If a caller
supplies its own cancelable token to the enumerator, that token takes
precedence; otherwise the token bound here drives cancellation.

**Testing consequence:** cancellation tests must drive the stream through the
helper (`AsyncEnumerableHelper.GetCommandOutput`), not just check that an
exception is raised. See [`CommandStreamingTests.cs`](
../Tests/Sezam.Tests/CommandStreamingTests.cs) for the two patterns:

- `CommandStream_Stops_When_Cancelled` — cancel part-way through a 1000-item
  stream; assert fewer than 1000 lines were consumed.
- `CommandStream_CancelledUpFront_Yields_Nothing` — cancel before consuming;
  assert zero lines.

## Command migration pattern

### Before (terminal-coupled)

```csharp
[Command]
public async Task View()
{
    var conferences = GetConferences();
    foreach (var conf in conferences)
        await session.terminal.Line("{0,-16} ...", conf.VolumeName, ...);
}
```

### After (streaming)

```csharp
[Command]
public async IAsyncEnumerable<string> View()
{
    string confPattern = session.cmdLine.GetToken();
    bool showAll = session.cmdLine.Switch("a");
    var conferences = GetConferences(showAll)
        .Where(c => EF.Functions.Like(c.Name, confPattern + "%"));
    await foreach (var g in conferences.DisplayOrder()
                        .AsAsyncEnumerable()
                        .WithCancellation(session.CancellationToken))
        yield return string.Format(CultureInfo.InvariantCulture,
            "{0,-16} {1,5} {2:MMM yyyy} - {3:MMM yyyy}",
            g.VolumeName, g.ConfTopics.Sum(t => t.NextSequence), g.FromDate, g.ToDate);
}
```

Key points:

- No `session.terminal` access inside the command.
- Bind `.WithCancellation(session.CancellationToken)` when the source is a
  query/stream so interruption stops the underlying enumeration.
- State-change commands (`SEEn`) still `return Task`, persist, and then
  `yield return` their confirmation line — mixing persistence and streaming in
  one method is fine.

## Migrated commands (`Commands/Conference/Conference.cs`)

| Line | Command            | Notes                                                        |
|------|--------------------|--------------------------------------------------------------|
| 82   | `View()`           | Lists conferences matching a name pattern; cancellation-bound. |
| 303  | `ConfDir(conf)`    | Helper: streams directory topics for one conference.         |
| 327  | `Directory()`      | Streams directory for the current conference.                |
| 372  | `List()`           | Streams message list; cancellation-bound.                    |
| 515  | `SEEn()`           | Updates seen-time (persistence) then yields confirmation.    |

`Read()` (line 385) is intentionally left as `async Task` — it is a terminal
writer command, not part of this batch.

## Partial matching and the "uppercase = minimum" convention

Commands are matched case-insensitively by prefix, but the **first character
after the matched prefix must be lowercase** for the match to succeed. The
command designer encodes the required minimum input in the command name's
capitalisation — hence `SEEn` (not `seen`): the uppercase `SEE` means the user
must type at least `"SEE"`.

This is enforced by `PartialMatch` in `CommandSet.cs`:

```csharp
private static bool PartialMatch(string command, string cmd)
{
    if (!command.StartsWith(cmd, StringComparison.OrdinalIgnoreCase))
        return false;
    var cmdLen = cmd.Length;
    return cmdLen == command.Length || char.IsLower(command[cmdLen]);
}
```

Implications:

- `SEEn`: `"s"` → `command[1]='E'` not lowercase → **no match**. `"se"` →
  `command[2]='E'` → **no match**. `"see"` → `command[3]='n'` lowercase →
  **match**. Minimum input is `see`.
- A full command name (`View`, `List`, `Directory`) has no uppercase-after, so
  it matches when typed in full regardless of case.
- This is independent of ambiguity: a command's minimum is dictated by its own
  capitalisation, not by whether other commands would collide.

Tests must invoke these with at least the minimum prefix (`"see"`, `"view"`,
`"list"`, `"dir"`), exactly as a real user would.

## Testing strategy

The reusable harness is `CommandStreamingTests.cs`. Its helpers:

- `OutputCapturingTerminal : MockTerminal` — records every `Line(...)` call in
  `OutputLines` (both overloads).
- `InMemoryTestHost` — supplies an in-memory `SezamDbContext` per test.
- `SeedConversation` / `BindUserConf` / `BindConference` — set up a
  conference, topic, message, and the current user's access.

Assertions check `terminal.OutputLines` (via a `ContainsLine` helper) and, for
`SEEn`, that the DB effect (`SeenTime`) also happened.

### Seeding gotchas (learned the hard way)

The query model has two filters that bit the initial tests:

1. **`topic.Id` is not stable until save.** `ConfMessage.TopicId` must be read
   *after* the topic is saved, not from an unsaved entity. Capturing it before
   `SaveChanges()` yields `0`, orphaning the message; `List`/`Read` (which
   query messages by `TopicId`) then return nothing. Fix: assign the FK after
   the topic save (`CommandStreamingTests.cs:83`).

2. **`UserConf` query filter is scoped to the current user.**
   `SezamDbContext.OnModelCreating` applies
   `.HasQueryFilter(uc => uc.UserId == UserId)` to `UserConf`, where `UserId`
   is a property on the DbContext. In tests the user's `Id` is only known after
   save, so `session.Db.UserId` must be set **after** `SeedConversation`
   (which saves the user), otherwise `GetConferences()` returns nothing
   (`CommandStreamingTests.cs:87`).

Both fixes are in `CommandStreamingTests.cs`; keep them in mind if new
streaming commands add their own seeding.

## Verification

```
dotnet build Sezam.sln          # 0 warnings, 0 errors
dotnet test  Sezam.sln          # full suite (CommandStreamingTests included)
```

The build is warning-clean; streaming methods produce no CS1998
("method has no body") warnings because they are genuine async iterators.
