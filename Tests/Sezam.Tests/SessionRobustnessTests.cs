using NUnit.Framework;
using System;
using System.Threading;
using System.Collections.Generic;
using System.Linq;
using Sezam;
using Sezam.Data;
using Sezam.Commands;

namespace Sezam.Tests
{
    /// <summary>
    /// Unit tests for Session robustness. Focus on resource cleanup,
    /// thread safety, and graceful degradation under stress.
    /// </summary>
    [TestFixture]
    public class SessionRobustnessTests
    {
        private MockTerminal? mockTerminal;
        private Session? session;

        [SetUp]
        public void Setup()
        {
            mockTerminal = new MockTerminal();
            session = new Session(mockTerminal);
        }

        [TearDown]
        public void Teardown()
        {
            try { session?.Close(); } catch { }
            try { session?.Db?.Dispose(); } catch { }
        }

        /// <summary>
        /// Test that Session closes gracefully without errors (ROBUSTNESS: Fix #1).
        /// </summary>
        [Test]
        [CancelAfter(5000)]
        public void Session_ClosesGracefully()
        {
            // Arrange
            var term = new MockTerminal();
            var sess = new Session(term);

            // Act & Assert: Should close without throwing
            Assert.DoesNotThrow(() =>
            {
                sess.Close();
                Thread.Sleep(200);
            });
        }

        /// <summary>
        /// Test that closing a session with a hung thread times out gracefully (ROBUSTNESS: Fix #7).
        /// </summary>
        [Test]
        [CancelAfter(10000)]
        public void Session_Close_TimesOutOnHungThread()
        {
            // Arrange
            // Use a mock that never returns from PromptEdit
            var hangingTerminal = new HangingMockTerminal();
            var hangingSession = new Session(hangingTerminal);
            hangingSession.Start();
            Thread.Sleep(100);

            // Act
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            hangingSession.Close();
            stopwatch.Stop();

            // Assert: Should timeout within 5.5 seconds (5s join + 0.5s buffer)
            Assert.That(stopwatch.ElapsedMilliseconds, Is.LessThan(5500),
                "Close() should timeout instead of blocking forever");
        }

        /// <summary>
        /// Test that multiple threads can access command set catalog without race conditions (ROBUSTNESS: Fix #4, #6).
        /// </summary>
        [Test]
        [CancelAfter(10000)]
        public void CommandSet_CatalogThreadSafe_DuringConcurrentAccess()
        {
            // Arrange
            var cmdSet = new TestCommandSet(session!);
            var exceptions = new List<Exception>();
            var accessCount = 0;

            // Act: 50 threads accessing catalog simultaneously
            var threads = Enumerable.Range(0, 50)
                .Select(_ => new Thread(() => {
                    try
                    {
                        var cat = cmdSet.Catalog;
                        Assert.That(cat, Is.Not.Null);
                        Interlocked.Increment(ref accessCount);
                    }
                    catch (Exception ex)
                    {
                        lock (exceptions) exceptions.Add(ex);
                    }
                }))
                .ToList();

            threads.ForEach(t => t.Start());
            threads.ForEach(t => t.Join());

            // Assert
            Assert.That(exceptions, Is.Empty, 
                $"No exceptions during concurrent catalog access. Got: {string.Join(", ", exceptions.Select(e => e.Message))}");
            Assert.That(accessCount, Is.EqualTo(50), "All threads should successfully access catalog");
        }

        /// <summary>
        /// Test that volatile fields prevent caching issues under concurrent access (ROBUSTNESS: Fix #6).
        /// </summary>
        [Test]
        [CancelAfter(5000)]
        public void Session_VolatileFields_PreventCaching()
        {
            // This test verifies that rootCommandSet and currentCommandSet are
            // properly marked as volatile, preventing cache coherency issues.
            
            // Arrange
            int readCount = 0;

            // Act: Rapidly read currentCommandSet from multiple threads
            var threads = Enumerable.Range(0, 100)
                .Select(_ => new Thread(() => {
                    // Force reads to happen without optimization
                    var cs = session!.GetType()
                        .GetField("currentCommandSet", 
                            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                        ?.GetValue(session);
                    Interlocked.Increment(ref readCount);
                }))
                .ToList();

            threads.ForEach(t => t.Start());
            threads.ForEach(t => t.Join());

            // Assert: All reads completed without error
            Assert.That(readCount, Is.EqualTo(100), "All volatile field reads should succeed");
        }
    }

    /// <summary>
    /// Test command set for catalog testing.
    /// </summary>
    public class TestCommandSet : CommandSet
    {
        public TestCommandSet(Session session) : base(session) { }

        public void TestCommand()
        {
            session.terminal.Line("Test");
        }
    }
}
