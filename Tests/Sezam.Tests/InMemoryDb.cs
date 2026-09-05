using System;
using Microsoft.EntityFrameworkCore;
using Sezam.Data;

namespace Sezam.Tests
{
    /// <summary>
    /// Test-side hook that substitutes an in-memory DbContext provider.
    ///
    /// Production assemblies (Sezam.Data, Console, Web) must never know a test
    /// database exists, so the production <see cref="Store.OptionsFactory"/> slot
    /// carries the override instead of a magic environment variable. Production
    /// code leaves this slot <c>null</c>; every test enables it in <c>[SetUp]</c>
    /// and clears it in <c>[TearDown]</c>.
    ///
    /// The database name is generated once per Enable() call and reused across
    /// every context built during that test, mirroring the previous
    /// SEZAM_TEST_DB behaviour where a single name was shared by all contexts in
    /// a fixture so seeded data is visible across GetNewContext()/session.Db.
    /// </summary>
    internal static class InMemoryDb
    {
        private static string? dbName;

        public static void Enable()
        {
            dbName = "SezamTest_" + Guid.NewGuid().ToString("N");
            Store.OptionsFactory = options => options.UseInMemoryDatabase(dbName);
        }

        public static void Disable()
        {
            Store.OptionsFactory = null;
        }
    }
}
