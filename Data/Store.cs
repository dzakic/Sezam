using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Sezam.Data.EF;

namespace Sezam.Data
{
    // Database context, per session
    public class SezamDbContext : DbContext
    {

        public int UserId { get; set; }

        public SezamDbContext(DbContextOptions<SezamDbContext> options) : base(options) { }


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

        public static SezamDbContext GetNewContext()
        {
            DbContextOptions<SezamDbContext> options;
            var optionsBuilder = new DbContextOptionsBuilder<SezamDbContext>();
            var connectionString = "server=" + ServerName + ";database=sezam;user=sezam;password=" + Password;

            options = optionsBuilder
                .UseMySql(connectionString, ServerVersion.AutoDetect(connectionString))
                .EnableSensitiveDataLogging()
                .UseLazyLoadingProxies()
                .Options;

            return new SezamDbContext(options);
        }

        private static IList<ISession> sessions;
        private static string serverName;
        private static string password;

        public static IList<ISession> Sessions { get => sessions; set => sessions = value; }
        public static string ServerName { get => serverName; set => serverName = value; }
        public static string Password { get => password; set => password = value; }
    }
}