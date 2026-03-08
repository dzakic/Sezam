using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Sezam;
using Sezam.Data;

namespace Sezam.Tests
{
    /// <summary>
    /// Unit tests for session management under stress.
    /// Focus on concurrent session handling, graceful shutdown, and resource cleanup.
    /// </summary>
    [TestFixture]
    public class ServerRobustnessTests
    {
        /// <summary>
        /// Test that multiple sessions can be created, used, and closed concurrently
        /// without deadlocks or resource leaks.
        /// </summary>
        [Test]
        [CancelAfter(30000)]
        public void Session_ConcurrentCreationAndClosure()
        {
            // Arrange
            const int sessionCount = 100;
            var sessions = new List<Session>();
            var closedCount = 0;
            object syncLock = new object();

            // Act: Create many sessions in parallel
            var threads = new List<Thread>();
            for (int i = 0; i < sessionCount; i++)
            {
                var thread = new Thread(() =>
                {
                    var term = new MockTerminal();
                    var sess = new Session(term);
                    
                    lock (sessions) { sessions.Add(sess); }
                    
                    // Simulate minimal session activity
                    Thread.Sleep(10);
                    
                    // Close session
                    try
                    {
                        sess.Close();
                        lock (syncLock) { closedCount++; }
                    }
                    catch (Exception ex)
                    {
                        Assert.Fail($"Unexpected exception during Close(): {ex.Message}");
                    }
                });
                threads.Add(thread);
                thread.Start();
            }

            // Wait for all sessions to complete
            foreach (var t in threads)
                t.Join(2000);

            // Assert
            Assert.That(closedCount, Is.GreaterThanOrEqualTo(sessionCount - 5),
                $"Most sessions should close successfully. Closed: {closedCount}/{sessionCount}");
        }

        /// <summary>
        /// Test that session Close() respects timeout when thread is hung.
        /// </summary>
        [Test]
        [CancelAfter(15000)]
        public void Session_Close_TimesOutOnHungThread()
        {
            // Arrange
            var hangingTerminal = new HangingMockTerminal();
            var session = new Session(hangingTerminal);
            _ = session.Run();
            Thread.Sleep(100);  // Let it start blocking

            // Act
            var stopwatch = Stopwatch.StartNew();
            session.Close();
            stopwatch.Stop();

            // Assert: Should timeout within 5.5 seconds (5s internal timeout + 0.5s buffer)
            Assert.That(stopwatch.ElapsedMilliseconds, Is.LessThan(5500),
                "Session.Close() should timeout on hung thread instead of blocking indefinitely");
        }

        /// <summary>
        /// Test that Store.Sessions list is thread-safe for concurrent access.
        /// </summary>
        [Test]
        [CancelAfter(10000)]
        public void Store_SessionsListThreadSafe_ConcurrentAccess()
        {
            // Arrange
            int readCount = 0;
            int writeCount = 0;
            int errorCount = 0;
            object syncLock = new object();

            var sessions = new List<Session>();
            for (int i = 0; i < 10; i++)
            {
                sessions.Add(new Session(new MockTerminal()));
            }

            // Act: Simulate concurrent Store.Sessions read/write
            var threads = new List<Thread>();
            
            // 30 reader threads
            for (int i = 0; i < 30; i++)
            {
                threads.Add(new Thread(() =>
                {
                    try
                    {
                        var list = Store.Sessions.ToList();  // Thread-safe read
                        lock (syncLock) { readCount++; }
                    }
                    catch (Exception)
                    {
                        lock (syncLock) { errorCount++; }
                    }
                }));
            }

            // Start all threads
            threads.ForEach(t => t.Start());
            threads.ForEach(t => t.Join(1000));

            // Cleanup
            foreach (var sess in sessions)
                try { sess?.Close(); } catch { }

            // Assert: No race conditions
            Assert.That(errorCount, Is.EqualTo(0), "No errors during concurrent access");
            Assert.That(readCount, Is.GreaterThanOrEqualTo(25), $"Most reads completed. Got: {readCount}");
            Assert.That(writeCount, Is.GreaterThanOrEqualTo(8), $"Most writes completed. Got: {writeCount}");
        }

        /// <summary>
        /// Test that multiple sessions can maintain isolated DbContext instances.
        /// </summary>
        [Test]
        [CancelAfter(10000)]
        public void Session_DbContextIsolation_MultipleInstances()
        {
            // Arrange
            var sessions = new List<Session>();
            var dbContexts = new List<object>();
            object syncLock = new object();

            // Act: Create 20 sessions and capture their contexts
            var threads = new List<Thread>();
            for (int i = 0; i < 20; i++)
            {
                threads.Add(new Thread(() =>
                {
                    var term = new MockTerminal();
                    var sess = new Session(term);
                    var ctx = sess.Db;
                    
                    lock (syncLock)
                    {
                        sessions.Add(sess);
                        dbContexts.Add(ctx);
                    }
                }));
            }

            threads.ForEach(t => t.Start());
            threads.ForEach(t => t.Join());

            // Assert: Each session has its own context
            var uniqueContexts = dbContexts.Distinct().Count();
            Assert.That(uniqueContexts, Is.EqualTo(20), "Each session should have a unique DbContext");

            // Cleanup
            foreach (var sess in sessions)
                try { sess?.Close(); } catch { }
        }

        /// <summary>
        /// Test that sessions can be created and destroyed rapidly without blocking.
        /// </summary>
        [Test]
        [CancelAfter(10000)]
        public void Session_RapidCreateDestroy_NoBlocking()
        {
            // Arrange
            int successCount = 0;
            int errorCount = 0;
            object syncLock = new object();
            
            var stopwatch = Stopwatch.StartNew();

            // Act: Rapidly create and close sessions
            var tasks = new List<Task>();
            for (int i = 0; i < 100; i++)
            {
                tasks.Add(Task.Run(() =>
                {
                    try
                    {
                        var term = new MockTerminal();
                        var sess = new Session(term);
                        // Minimal activity
                        Thread.Sleep(1);
                        sess.Close();
                        lock (syncLock) { successCount++; }
                    }
                    catch (Exception)
                    {
                        lock (syncLock) { errorCount++; }
                    }
                }));
            }

            Task.WaitAll(tasks.ToArray());
            stopwatch.Stop();

            // Assert: Should complete quickly without blocking
            Assert.That(stopwatch.ElapsedMilliseconds, Is.LessThan(5000),
                "Creating and closing 100 sessions should not take more than 5 seconds");
            Assert.That(errorCount, Is.EqualTo(0), "No errors during rapid create/destroy");
            Assert.That(successCount, Is.GreaterThanOrEqualTo(95), $"Most operations succeeded. Got: {successCount}");
        }
    }
}
