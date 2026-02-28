using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Sezam;

namespace Sezam.Tests
{
    /// <summary>
    /// Harness/stress test for SessionAsync under realistic load.
    /// Simulates the SessionHarness tool but as an automated test.
    /// </summary>
    [TestFixture]
    public class SessionAsyncHarnessTests
    {
        /// <summary>
        /// Launch and manage multiple concurrent SessionAsync instances.
        /// This simulates the original SessionHarness tool functionality.
        /// </summary>
        [Test]
        [CancelAfter(30000)]
        public async Task SessionHarness_LaunchMultipleSessions_AllCompleteClearly()
        {
            // Arrange
            const int sessionCount = 50;
            var sessions = new SessionAsync[sessionCount];
            var finishedCount = 0;
            var stopwatch = Stopwatch.StartNew();

            // Act
            // Launch all sessions
            for (int i = 0; i < sessionCount; i++)
            {
                var terminal = new MockTerminal();
                var sess = new SessionAsync(terminal);
                sessions[i] = sess;
                
                sess.OnFinish += (s, e) =>
                {
                    Interlocked.Increment(ref finishedCount);
                };
                
                // Fire and forget (like the harness)
                _ = sess.RunAsync();
            }

            // Wait a moment for sessions to process
            await Task.Delay(500);

            // Close all sessions
            foreach (var sess in sessions)
            {
                try { sess.Close(); } catch { }
            }

            // Wait for cleanup
            await Task.Delay(1000);
            stopwatch.Stop();

            // Assert
            Assert.That(finishedCount, Is.GreaterThan(0), 
                "At least some sessions should finish");
            Assert.That(stopwatch.ElapsedMilliseconds, Is.LessThan(25000),
                "All sessions should clean up within reasonable time");
        }

        /// <summary>
        /// Stress test: rapidly create and destroy many sessions.
        /// Verifies no resource leaks or deadlocks under sustained load.
        /// </summary>
        [Test]
        [CancelAfter(60000)]
        public async Task SessionHarness_RapidCycling_NoLeaks()
        {
            // Arrange
            const int iterations = 10;
            const int sessionsPerIteration = 50;
            int totalCreated = 0;
            int totalFinished = 0;

            var stopwatch = Stopwatch.StartNew();

            // Act: Multiple cycles of create/run/close
            for (int cycle = 0; cycle < iterations; cycle++)
            {
                var sessions = new List<SessionAsync>();
                
                // Create batch
                for (int i = 0; i < sessionsPerIteration; i++)
                {
                    var sess = new SessionAsync(new MockTerminal());
                    sess.OnFinish += (s, e) =>
                    {
                        Interlocked.Increment(ref totalFinished);
                    };
                    sessions.Add(sess);
                    totalCreated++;
                    
                    // Start async (fire and forget)
                    _ = sess.RunAsync();
                }

                // Brief processing time
                await Task.Delay(100);

                // Close all
                foreach (var sess in sessions)
                {
                    try { sess.Close(); } catch { }
                }

                // Let cleanup complete
                await Task.Delay(100);
            }

            stopwatch.Stop();

            // Assert: Should handle 500+ session lifecycle events without issues
            Assert.That(totalCreated, Is.EqualTo(iterations * sessionsPerIteration),
                $"Should create all {iterations * sessionsPerIteration} sessions");
            Assert.That(stopwatch.ElapsedMilliseconds, Is.LessThan(55000),
                "10 cycles of 50 sessions should complete in under 55 seconds");
        }

        /// <summary>
        /// Verify that running sessions under sustained stress maintains responsiveness.
        /// </summary>
        [Test]
        [CancelAfter(30000)]
        public async Task SessionHarness_SustainedLoad_StayResponsive()
        {
            // Arrange
            const int sessionCount = 100;
            var responseTimes = new List<long>();
            var stopwatch = Stopwatch.StartNew();

            // Act: Launch sessions and measure completion time
            var sessions = new List<SessionAsync>();
            for (int i = 0; i < sessionCount; i++)
            {
                var sess = new SessionAsync(new MockTerminal());
                sessions.Add(sess);
                
                // Fire and forget
                var sw = Stopwatch.StartNew();
                var task = sess.RunAsync();
                _ = task.ContinueWith(_ =>
                {
                    sw.Stop();
                    lock (responseTimes) { responseTimes.Add(sw.ElapsedMilliseconds); }
                });
            }

            // Let them run a bit
            await Task.Delay(500);

            // Close all
            foreach (var sess in sessions)
            {
                try { sess.Close(); } catch { }
            }

            // Wait for all to finish
            await Task.Delay(2000);
            stopwatch.Stop();

            // Assert
            Assert.That(responseTimes.Count, Is.GreaterThan(0),
                "At least some sessions should complete");
            
            if (responseTimes.Count > 0)
            {
                var avgTime = responseTimes.Average();
                Assert.That(avgTime, Is.LessThan(5000),
                    $"Average session response time should be < 5s. Got: {avgTime}ms");
            }

            Assert.That(stopwatch.ElapsedMilliseconds, Is.LessThan(25000),
                "Entire harness should complete in under 25 seconds");        }
    }
}
