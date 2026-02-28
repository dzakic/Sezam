using System;
using System.Collections.Generic;
using System.Diagnostics;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Microsoft.Extensions.Configuration;
using Sezam.Data.EF;

namespace Sezam.Data
{
    // Database context, per session
    public class SezamDbContext(DbContextOptions options) : DbContext(options)
    {

        public int UserId { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<UserConf>()
                   .HasQueryFilter(uc => uc.UserId == UserId)
                   .HasKey(c => new { c.UserId, c.ConferenceId });
            modelBuilder.Entity<UserTopic>()
                   .HasKey(c => new { c.UserId, c.TopicId });

            var userConfconverter = new EnumToNumberConverter<UserConf.UserConfStat, int>();
            modelBuilder.Entity<UserConf>()
                        .Property(e => e.Status)
                        .HasConversion(userConfconverter);

            modelBuilder.Entity<UserTopic>()
                .HasQueryFilter(ut => ut.UserId == UserId);

        }

        public override int SaveChanges()
        {
            // CheckDates();
            return base.SaveChanges();
        }

        public DbSet<User> Users { get; set; }
        public DbSet<Conference> Conferences { get; set; }
        public DbSet<ConfTopic> ConfTopics { get; set; }
        public DbSet<ConfMessage> ConfMessages { get; set; }
        public DbSet<UserConf> UserConfs { get; set; }
    }

    // A global object accessible to all sessions
    public static class Store
    {

        public static DbContextOptionsBuilder GetOptionsBuilder(DbContextOptionsBuilder builder)
        {
            var ConnectionString = $"server={ServerName};database=sezam;user=sezam;password={Password}";
            Debug.WriteLine("ServerName: " + Data.Store.ServerName);
            return builder
                .UseMySQL(ConnectionString)
                .EnableSensitiveDataLogging()
                .UseLazyLoadingProxies();
        }

        public static SezamDbContext GetNewContext()
        {
            var optionsBuilder = GetOptionsBuilder(new DbContextOptionsBuilder());
            var options = optionsBuilder.Options;
            return new SezamDbContext(options);
        }

        // underlying storage for sessions.  original implementation exposed a
        // mutable list directly which allowed concurrent readers/writers to
        // race.  the fix introduces a private lock and only returns a copy of
        // the list to callers.  the setter is similarly guarded.
        private static readonly object _sessionLock = new object();
        private static List<ISession> _sessionsList = new List<ISession>();

        // volatile ensures that reads/writes of the primitive string fields are
        // not cached in registers; it's mostly defensive since they are written
        // only during startup.
        private static volatile string serverName;
        private static volatile string password;

        public static IList<ISession> Sessions
        {
            get
            {
                lock (_sessionLock)
                {
                    // return a shallow copy to prevent callers from modifying our
                    // internal list without synchronization.
                    return new List<ISession>(_sessionsList);
                }
            }
            set
            {
                lock (_sessionLock)
                {
                    _sessionsList.Clear();
                    if (value != null)
                        _sessionsList.AddRange(value);
                }
            }
        }

        public static string ServerName
        {
            get { return serverName; }
            set { serverName = value; }
        }

        public static string Password
        {
            get { return password; }
            set { password = value; }
        }
    }
}