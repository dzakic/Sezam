# Streaming Command Refactoring Plan

## Goal
Refactor command output from direct `session.terminal.Line()` to returning `IAsyncEnumerable<string>` for testability and loose coupling.

## Current Architecture
- Commands decorated with `[Command]` in `CommandSet` classes
- Commands call `await session.terminal.Line()` directly
- Reflection-based execution in `CommandSet.InvokeCommand()`
- Returns `Task` (void or Task) via reflection

## Proposed Components

### 1. CommandOutputAttribute.cs
```csharp
[AttributeUsage(AttributeTargets.Method)]
public class CommandOutputAttribute : Attribute
{
    // Mark commands that return IAsyncEnumerable<string>
}
```

### 2. AsyncEnumerableHelper.cs
```csharp
public static class AsyncEnumerableHelper
{
    public static async Task<IAsyncEnumerable<string>> ExecuteCommandAsync(
        CommandSet cmdSet, string commandName, CancellationToken cancellationToken)
    {
        var command = cmdSet.GetCommandMethod(commandName);
        if (command is null)
            throw new ArgumentException($"Unknown command: {commandName}");

        if (command.ReturnType == typeof(void))
        {
            var result = command.Invoke(cmdSet, null);
            await (Task)result;
            return new AsyncEnumerable<string>(new[] { "Command completed" });
        }

        if (command.ReturnType == typeof(Task))
        {
            var result = command.Invoke(cmdSet, null);
            await (Task)result;
            return new AsyncEnumerable<string>(new[] { "Command completed" });
        }

        if (command.ReturnType.IsAssignableTo(typeof(IAsyncEnumerable<string>)))
        {
            var result = command.Invoke(cmdSet, null);
            return (IAsyncEnumerable<string>)result;
        }

        return new AsyncEnumerable<string>(new[] { "Command completed" });
    }

    public static async Task ExecuteStreamingCommand(
        CommandSet cmdSet, string commandName, CancellationToken cancellationToken)
    {
        var stream = await ExecuteCommandAsync(cmdSet, commandName, cancellationToken);

        try
        {
            await foreach (var line in stream.WithCancellation(cancellationToken))
            {
                await cmdSet.Session.Terminal.Line(line);
            }
        }
        catch (TerminalException e) when (e.Code == TerminalException.CodeType.UserOutputInterrupted)
        {
            throw; // Let Session.Run() catch and handle
        }
    }
}
```

### 3. AsyncEnumerable.cs
```csharp
public class AsyncEnumerable : IAsyncEnumerable<string>
{
    private readonly IEnumerable<string> _items;
    private readonly Func<IEnumerable<string>, IAsyncEnumerator<string>> _asyncEnumeratorFactory;

    public AsyncEnumerable(IEnumerable<string> items)
        : this(items, null)
    {
    }

    public AsyncEnumerable(Func<IEnumerable<string>, IAsyncEnumerator<string>> asyncEnumeratorFactory)
        : this(null, asyncEnumeratorFactory)
    {
    }

    private AsyncEnumerable(IEnumerable<string> items, Func<IEnumerable<string>, IAsyncEnumerator<string>> asyncEnumeratorFactory)
    {
        _items = items ?? Enumerable.Empty<string>();
        _asyncEnumeratorFactory = asyncEnumeratorFactory;
    }

    public IAsyncEnumerator<string> GetAsyncEnumerator(CancellationToken cancellationToken = default)
    {
        if (_asyncEnumeratorFactory != null)
            return _asyncEnumeratorFactory(_items);

        return new AsyncEnumerator(_items.GetEnumerator(), cancellationToken);
    }

    private class AsyncEnumerator : IAsyncEnumerator<string>
    {
        private readonly IEnumerator<string> _enumerator;
        private readonly CancellationToken _cancellationToken;

        public AsyncEnumerator(IEnumerator<string> enumerator, CancellationToken cancellationToken)
        {
            _enumerator = enumerator;
            _cancellationToken = cancellationToken;
        }

        public string Current => _enumerator.Current;

        public async ValueTask<bool> MoveNextAsync()
        {
            if (_cancellationToken.IsCancellationRequested)
                return false;

            await Task.Yield();
            bool hasMore = _enumerator.MoveNext();
            return hasMore;
        }

        public ValueTask DisposeAsync()
        {
            _enumerator.Dispose();
            return default;
        }
    }
}
```

### 4. Update CommandSet.cs
```csharp
// Update GetMethods() to include streaming commands:
private IEnumerable<MethodInfo> GetMethods() =>
    GetType().GetMethods(BindingFlags.Public | BindingFlags.Instance)
        .Where(m => (m.IsPublic || m.IsDefined(typeof(CommandAttribute)))
            && (m.ReturnType == typeof(void)
                || m.ReturnType == typeof(Task)
                || m.ReturnType.IsAssignableTo(typeof(IAsyncEnumerable<string>)))
            && m.GetParameters().Length == 0;

// Add streaming execution:
public async Task<bool> ExecuteCommandStreaming(string cmd)
{
    var command = GetCommandMethod(cmd);
    if (command is null)
        return false;

    if (!UserHasAccess(command) || !UserHasAccessForSwitches(command))
    {
        await session.terminal.Line("Access denied");
        return true;
    }

    try
    {
        var stream = await AsyncEnumerableHelper.ExecuteCommandAsync(this, cmd, session.CancellationToken);
        await AsyncEnumerableHelper.ExecuteStreamingCommand(this, cmd, session.CancellationToken);
        return true;
    }
    catch (Exception e)
    {
        await session.terminal.Line($"Command error: {e.Message}");
        return false;
    }
}

// Keep ExecuteCommand() for backward compatibility
```

### 5. Update Session.cs
```csharp
// Add property:
public CancellationToken CancellationToken => cts.Token;
```

## Command Migration Pattern

### Before:
```csharp
[Command]
public async Task View()
{
    var conferences = GetConferences();
    foreach (var conf in conferences)
    {
        await session.terminal.Line($"Conf: {conf.Name}");
    }
}
```

### After (Streaming):
```csharp
[CommandOutput]
public async Task View()
{
    yield return "Conference List:";
    yield return "==========";

    var conferences = await GetConferencesAsync();
    foreach (var conf in conferences)
    {
        yield return $"Conf: {conf.Name}";
    }

    yield return "==========";
    yield return "Total: X conferences";
}
```

### Mixed Streaming (with state changes):
```csharp
[CommandOutput]
public async Task SEEn()
{
    bool allConferences = session.cmdLine.Switch("a");

    yield return "Updating seen messages...";
    yield return "";

    await UpdateSeenTime(allConferences);

    yield return "Seen time updated successfully!";
    yield return "";
    yield return "Session saved.";
}

private async Task UpdateSeenTime(bool allConferences)
{
    await session.Db.SaveChangesAsync();
}
```

## Testing Strategy

### MockTerminal Enhancement:
```csharp
public class TestTerminal : MockTerminal
{
    public List<string> OutputLines { get; } = new();

    public override async Task Line(string text = "")
    {
        OutputLines.Add(text);
    }

    public override async Task Line(string text = "", params object[] args)
    {
        OutputLines.Add(string.Format(text, args));
    }

    public override async Task Text(string text)
    {
        OutputLines.Add(text);
    }

    public void Clear()
    {
        OutputLines.Clear();
    }
}
```

### Test Pattern:
```csharp
[Test]
public async Task CommandStreaming_ReturnsExpectedOutput()
{
    var testTerminal = new TestTerminal();
    var session = new Session(testTerminal, NullLogger<Session>.Instance);

    var commandSet = session.GetCommandProcessor(typeof(Conference));
    session.currentCommandSet = commandSet;

    await session.ExecCmd("view");

    Assert.That(testTerminal.OutputLines, Has.Count.EqualTo(X));
    Assert.That(testTerminal.OutputLines, Has.Some.Containing("Conf: General"));
    Assert.That(testTerminal.OutputLines, Has.Some.Containing("Total: X"));
}
```

## Migration Strategy

### Phase 1: Infrastructure (Task 1)
- Create CommandOutputAttribute.cs
- Create AsyncEnumerableHelper.cs
- Create AsyncEnumerable.cs
- Update Session.cs to add CancellationToken property
- Update CommandSet.cs GetMethods()

### Phase 2: Conference Commands (Task 3)
- Migrate View()
- Migrate Directory()
- Migrate List()
- Migrate ConfDir()

### Phase 3: Chat/Mail Commands (Task 4-5)
- Migrate Chat.List()
- Migrate Mail.List()

### Phase 4: Tests (Task 6)
- Add tests for streaming commands
- Add pagination interruption tests

### Phase 5: Verification (Task 7)
- Run full test suite
- Fix failing tests
- Verify backward compatibility
