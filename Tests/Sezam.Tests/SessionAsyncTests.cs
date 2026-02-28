using NUnit.Framework;
using System;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Diagnostics;
using Sezam;

namespace Sezam.Tests
{
    /// <summary>
    /// Unit tests for SessionAsync. Focus on async/await correctness,
    /// cancellation tokens, and timeout behavior.
    /// </summary>
    [TestFixture]
    public class SessionAsyncTests
    {
        private MockTerminal? mockTerminal;
        private SessionAsync? session;

        [SetUp]
        public void Setup()
        {
            mockTerminal = new MockTerminal();
            session = new SessionAsync(mockTerminal);
        }

        [TearDown]
        public void Teardown()
        {
            try { session?.Close(); } catch { }
            try { session?.Db?.Dispose(); } catch { }
        }

        /// <summary>
        /// Test that RunAsync completes cleanly without blocking main thread.
        /// </summary>
        [Test]
        [CancelAfter(5000)]
        public async Task SessionAsync_RunAsync_DoesNotBlock()
        {
            // Arrange
            var startTime = Stopwatch.StartNew();

            // Act
            var runTask = session!.RunAsync();
            
            // Give it a moment to start processing
            await Task.Delay(100);
            
            session.Close();
            await runTask;
            startTime.Stop();

            // Assert: Should complete without hanging
            Assert.That(startTime.ElapsedMilliseconds, Is.LessThan(2000), 
                "RunAsync should complete quickly when terminal is closed");
        }

        /// <summary>
        /// Test that multiple SessionAsync instances run concurrently on thread pool.
        /// </summary>
        [Test]
        [CancelAfter(10000)]
        public async Task SessionAsync_MultipleSessions_RunConcurrently()
        {
            // Arrange
            int completedCount = 0;
            var sessions = new List<SessionAsync>();
            var tasks = new List<Task>();

            // Act: Launch 10 concurrent sessions
            for (int i = 0; i < 10; i++)
            {
                var term = new MockTerminal();
                var sess = new SessionAsync(term);
                sessions.Add(sess);
                
                var task = sess.RunAsync().ContinueWith(_ => 
                {
                    Interlocked.Increment(ref completedCount);
                });
                tasks.Add(task);
            }

            // Give them time to start
            await Task.Delay(100);

            // Close all at once
            foreach (var sess in sessions)
                sess.Close();

            // Wait for all to finish
            await Task.WhenAll(tasks);

            // Assert
            Assert.That(completedCount, Is.EqualTo(10), "All sessions should complete");
        }

        /// <summary>
        /// Test that Close() on async session cancels the token properly.
        /// </summary>
        [Test]
        [CancelAfter(5000)]
        public async Task SessionAsync_Close_CancelsCancellationToken()
        {
            // Arrange
            var runTask = session!.RunAsync();
            await Task.Delay(50);

            // Act
            var stopwatch = Stopwatch.StartNew();
            session.Close();
            await runTask;
            stopwatch.Stop();

            // Assert: Should exit quickly via cancellation
            Assert.That(stopwatch.ElapsedMilliseconds, Is.LessThan(2000),
                "Close() should trigger cancellation token");
        }

        /// <summary>
        /// Test that SessionAsync properly cleans up resources.
        /// </summary>
        [Test]
        [CancelAfter(5000)]
        public async Task SessionAsync_Cleanup_FreesResources()
        {
            // Arrange
            var runTask = session!.RunAsync();
            await Task.Delay(50);

            // Act & Assert: Should clean up without throwing
            Assert.DoesNotThrowAsync(async () =>
            {
                session.Close();
                await runTask;
                await Task.Delay(200);
            });
        }
    }
}
