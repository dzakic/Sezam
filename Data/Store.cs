using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Microsoft.Extensions.Configuration;
using Sezam.Data.EF;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;


namespace Sezam.Data
{
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
            return base.SaveChanges();
        }

        public DbSet<User> Users { get; set; }
        public DbSet<Conference> Conferences { get; set; }
        public DbSet<ConfTopic> ConfTopics { get; set; }
        public DbSet<ConfMessage> ConfMessages { get; set; }
        public DbSet<UserConf> UserConfs { get; set; }
    }

    public static class Store
    {
        public static void ConfigureFrom(IConfiguration configuration)
        {
            DbName = ResolveConfigValue(configuration, "DbName") ?? "sezam";
            ServerName = ResolveConfigValue(configuration, "ServerName");
            Password = ResolveConfigValue(configuration, "Password");
        }

        public static string ResolveConfigValue(IConfiguration configuration, string name) =>
            Environment.GetEnvironmentVariable(name)
                ?? Environment.GetEnvironmentVariable($"ConnectionStrings__{name}")
                ?? configuration?.GetConnectionString(name)
                ?? configuration?[$"ConnectionStrings:{name}"]
                ?? configuration?[name];

        public static DbContextOptionsBuilder GetOptionsBuilder(DbContextOptionsBuilder builder)
        {
            var connectionString = $"server={ServerName};database={DbName};user=sezam;password={Password}";
            Debug.WriteLine($"ServerName: {ServerName}");
            return builder
                .UseMySQL(connectionString)
                .EnableSensitiveDataLogging()
                .UseLazyLoadingProxies();
        }

        public static SezamDbContext GetNewContext()
        {
            var optionsBuilder = GetOptionsBuilder(new DbContextOptionsBuilder());
            return new SezamDbContext(optionsBuilder.Options);
        }

        public static readonly ConcurrentDictionary<Guid, ISession> Sessions = new();


        public static void AddSession(ISession session)
        {
            Sessions.TryAdd(session.Id, session);
        }
        public static void RemoveSession(ISession session)
        {
            Sessions.TryRemove(session.Id, out _);
        }

        public static string ServerName { get; private set; }
        public static string Password { get; private set; }
        public static string DbName { get; private set; }
    }
}