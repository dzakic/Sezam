namespace Sezam.Commands
{
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.Runtime.CompilerServices;
    using System.Threading;
    using System.Threading.Tasks;

    /// <summary>
    /// Bridges command invocation to an <see cref="IAsyncEnumerable{T}"/> stream of output lines.
    ///
    /// Commands that return <c>IAsyncEnumerable&lt;string&gt;</c> (async iterators that
    /// <c>yield return</c> lines) are decoupled from the terminal: their output can be
    /// written to the session terminal, redirected to any <see cref="TextWriter"/>, or
    /// captured by a test. Commands returning <c>void</c> or <c>Task</c> keep writing to
    /// the terminal themselves and contribute nothing to the stream.
    ///
    /// The stream is cancellation-aware: when the supplied token is cancelled the consumer
    /// stops receiving lines, letting a long-running command be abandoned part-way through.
    /// </summary>
    public static class AsyncEnumerableHelper
    {
        /// <summary>
        /// Invokes the named command and exposes its output as a stream of lines.
        /// </summary>
        /// <param name="cmdSet">The command set that owns the command.</param>
        /// <param name="commandName">Command name (partial match, as resolved by the catalog).</param>
        /// <param name="cancellationToken">Cancels generation of the remaining lines.</param>
        public static async IAsyncEnumerable<string> GetCommandOutput(
            CommandSet cmdSet, string commandName,
            [EnumeratorCancellation] CancellationToken cancellationToken = default)
        {
            var command = cmdSet.GetCommandMethod(commandName)
                ?? throw new ArgumentException($"Unknown command: {commandName}");

            if (command.ReturnType == typeof(void))
            {
                command.Invoke(cmdSet, null);
                yield break;
            }

            if (command.ReturnType == typeof(Task))
            {
                await (Task)command.Invoke(cmdSet, null);
                yield break;
            }

            if (command.ReturnType.IsAssignableTo(typeof(IAsyncEnumerable<string>)))
            {
                var stream = (IAsyncEnumerable<string>)command.Invoke(cmdSet, null);
                await foreach (var line in stream.WithCancellation(cancellationToken))
                    yield return line;
            }
            else
            {
                throw new NotSupportedException(
                    $"Command '{commandName}' has unsupported return type '{command.ReturnType.Name}'. " +
                    "Streaming commands must return IAsyncEnumerable<string>.");
            }
        }

        /// <summary>
        /// Streams the command's output to the session terminal, line by line.
        /// </summary>
        public static async Task ExecuteStreamingAsync(CommandSet cmdSet, string commandName, CancellationToken cancellationToken)
        {
            await foreach (var line in GetCommandOutput(cmdSet, commandName, cancellationToken))
                await cmdSet.session.terminal.Line(line);
        }

        /// <summary>
        /// Streams the command's output to an arbitrary writer (e.g. a file),
        /// enabling command output redirection independent of the terminal.
        /// </summary>
        public static async Task ExecuteToWriterAsync(CommandSet cmdSet, string commandName, TextWriter writer, CancellationToken cancellationToken)
        {
            await foreach (var line in GetCommandOutput(cmdSet, commandName, cancellationToken))
                await writer.WriteLineAsync(line);
        }
    }

    /// <summary>
    /// Adapts any <see cref="IAsyncEnumerable{T}"/> so its consumption honours a cancellation
    /// token. The underlying stream is asked to stop between items; the consumer simply sees
    /// the enumeration end rather than receiving a throw.
    /// </summary>
    public static class AsyncEnumerableExtensions
    {
        /// <summary>
        /// Wraps <paramref name="source"/> so it stops when <paramref name="cancellationToken"/>
        /// is cancelled. If the caller also supplies a cancelable token to the enumerator it takes
        /// precedence; otherwise the token bound here drives cancellation.
        /// </summary>
        public static IAsyncEnumerable<T> WithCancellation<T>(this IAsyncEnumerable<T> source, CancellationToken cancellationToken) =>
            new CancellableEnumerable<T>(source, cancellationToken);

        private sealed class CancellableEnumerable<T> : IAsyncEnumerable<T>
        {
            private readonly IAsyncEnumerable<T> _source;
            private readonly CancellationToken _cancellationToken;

            public CancellableEnumerable(IAsyncEnumerable<T> source, CancellationToken cancellationToken)
            {
                _source = source;
                _cancellationToken = cancellationToken;
            }

            public IAsyncEnumerator<T> GetAsyncEnumerator(CancellationToken cancellationToken = default)
            {
                CancellationToken token = cancellationToken.CanBeCanceled ? cancellationToken : _cancellationToken;
                return new CancellableEnumerator<T>(_source.GetAsyncEnumerator(token), token);
            }
        }

        private sealed class CancellableEnumerator<T> : IAsyncEnumerator<T>
        {
            private readonly IAsyncEnumerator<T> _source;
            private readonly CancellationToken _cancellationToken;

            public CancellableEnumerator(IAsyncEnumerator<T> source, CancellationToken cancellationToken)
            {
                _source = source;
                _cancellationToken = cancellationToken;
            }

            public T Current => _source.Current;

            public async ValueTask<bool> MoveNextAsync()
            {
                if (_cancellationToken.IsCancellationRequested)
                    return false;
                return await _source.MoveNextAsync();
            }

            public ValueTask DisposeAsync() => _source.DisposeAsync();
        }
    }
}
