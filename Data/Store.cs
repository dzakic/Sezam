using System;
using System.Collections.Generic;
using System.Data.SqlTypes;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Sezam.Data.EF;

namespace Sezam.Data
{
    // Database context, per session
    public class SezamDbContext : DbContext
    {

        public int UserId { get; set; }

        private readonly string serverName;
        private readonly string password;

        public SezamDbContext(string ServerName, string Password) : base()
        {
            serverName = ServerName;
            password = Password;
        }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            _ = optionsBuilder
                .UseMySql("server=" + serverName + ";database=sezam;user=sezam;password=" + password)
                .EnableSensitiveDataLogging()
                .UseLazyLoadingProxies();
        }

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

        #region unused
        private void CheckDates()
        {

            // On ConfMessage save, update Conf oldest and newest message
            var msgs = ChangeTracker.Entries<ConfMessage>();
            foreach (var msg in msgs)
            {
                if (msg.Entity.Topic.Conference.FromDate == null || msg.Entity.Time < msg.Entity.Topic.Conference.FromDate)
                    msg.Entity.Topic.Conference.FromDate = msg.Entity.Time;
                if (msg.Entity.Topic.Conference.ToDate == null || msg.Entity.Time > msg.Entity.Topic.Conference.ToDate)
                    msg.Entity.Topic.Conference.ToDate = msg.Entity.Time;
            }

            foreach (var change in ChangeTracker.Entries())
            {
                var values = change.CurrentValues;
                foreach (var prop in values.Properties)
                {
                    var value = values[prop.Name];
                    if (value is DateTime date)
                    {
                        if (date < SqlDateTime.MinValue.Value)
                        {
                            System.Diagnostics.Debug.WriteLine("Fix {0} {1} to {2}", prop.Name, value, SqlDateTime.MinValue.Value);
                            values[prop.Name] = SqlDateTime.MinValue.Value;
                        }
                        else if (date > SqlDateTime.MaxValue.Value)
                        {
                            System.Diagnostics.Debug.WriteLine("Fix {0} {1} to {2}", prop.Name, value, SqlDateTime.MaxValue.Value);
                            values[prop.Name] = SqlDateTime.MaxValue.Value;
                        }
                    }
                }
            }
        }
        #endregion

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
            return new SezamDbContext(ServerName, password);
        }

        private static IList<ISession> sessions;
        private static string serverName;
        private static string password;

        public static IList<ISession> Sessions { get => sessions; set => sessions = value; }
        public static string ServerName { get => serverName; set => serverName = value; }
        public static string Password { get => password; set => password = value; }
    }
}