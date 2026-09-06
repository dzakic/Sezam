using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Sezam;
using Sezam.Data;

namespace Sezam.Tests
{
    /// <summary>
    /// Test-side DI host that supplies an in-memory <see cref="SezamDbContext"/>.
    ///
    /// Unlike the previous static <c>Store.OptionsFactory</c> slot, this owns a
    /// real <see cref="ServiceProvider"/> created once per test and holds a single
    /// scope for the host's lifetime. Every context resolved from the scope
    /// (seeding, asserting, and the session under test) binds to the same
    /// in-memory database, so production code never references the InMemory
    /// provider and no static test hook is shared between fixtures.
    /// </summary>
    internal sealed class InMemoryTestHost : IDisposable
    {
        private readonly ServiceProvider provider;
        private readonly IServiceScope scope;

        public InMemoryTestHost()
        {
            var dbName = "SezamTest_" + Guid.NewGuid().ToString("N");
            var services = new ServiceCollection();
            services.AddDbContext<SezamDbContext>(options => options.UseInMemoryDatabase(dbName));
            provider = services.BuildServiceProvider();
            scope = provider.CreateScope();
        }

        public SezamDbContext CreateContext() =>
            scope.ServiceProvider.GetRequiredService<SezamDbContext>();

        public Session CreateSession(ITerminal terminal)
        {
            Func<SezamDbContext> factory = () => scope.ServiceProvider.GetRequiredService<SezamDbContext>();
            return new Session(terminal, NullLogger<Session>.Instance, factory);
        }

        public void Dispose()
        {
            scope.Dispose();
            provider.Dispose();
        }
    }
}
