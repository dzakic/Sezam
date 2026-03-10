using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Sezam.Data.EF;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Xml.Linq;


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

            // Configure self-referencing relationship for ConfMessage
            modelBuilder.Entity<ConfMessage>()
                .HasOne(m => m.ParentMessage)
                .WithMany()
                .HasForeignKey(m => m.ParentMessageId)
                .OnDelete(DeleteBehavior.Restrict);
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
            // Database Configuration
            string DbHost = ResolveConfigValue(configuration, "DB_HOST", "DbHost");
            string DbName = ResolveConfigValue(configuration, "DB_NAME", "DbName") ?? "sezam";
            string Password = ResolveConfigValue(configuration, "DB_PASSWORD", "DbPassword");

            if (!string.IsNullOrEmpty(DbHost))
            {
                DbConnectionString = $"server={DbHost};database={DbName};user=sezam;password={Password}";
            } else
                DbConnectionString = ResolveConfigValue(configuration, "SezamDb") 
                    ?? ResolveConfigValue(configuration, "Database") 
                    ?? ResolveConfigValue(configuration, "Db");

            Trace.TraceInformation($"Database Connection: '{DbConnectionString}'");

            // Redis Configuration
            string redisHost = ResolveConfigValue(configuration, "REDIS_HOST", "RedisHost");
            if (!string.IsNullOrWhiteSpace(redisHost))
            {
                // Infer connection string from host (add default port if not present)
                RedisConnectionString = redisHost.Contains(":") ? redisHost : $"{redisHost}:6379";
            }
            else
            {
                RedisConnectionString = ResolveConfigValue(configuration, "Redis");
            }
            logger.LogInformation($"Redis Connection: '{RedisConnectionString}'");
        }

        public static string ResolveConfigValue(IConfiguration configuration, params string[] names)
        {
            foreach (var name in names)
            {
                var value = configuration?[name]
                    ?? configuration?.GetConnectionString(name)
                    ?? configuration?[$"{name}:ConnectionString"]
                    ?? configuration?[$"ConnectionStrings:{name}"];
                if (value != null)
                {
                    logger.LogInformation($"Resolved config value for '{name}': {(string.IsNullOrEmpty(value) ? "null" : value)}");
                    return value;
                }
                // Trace.WriteLine($"Tried resolving config for '{name}', no luck.");
            }
            return null;
        }

        public static DbContextOptionsBuilder GetOptionsBuilder(DbContextOptionsBuilder builder)
        {
            return builder
                .UseMySQL(DbConnectionString)
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

        // Database Configuration Properties
        public static string DbConnectionString { get; private set; }

        // Redis Configuration Properties
        public static string RedisConnectionString { get; private set; }
        // Redis is enabled if connection string is not empty            
        public static bool RedisEnabled => !RedisConnectionString.IsWhiteSpace();

        // Message Broadcaster Singleton (dynamic type to avoid circular dependency)
        public static dynamic MessageBroadcaster { get; set; }

        public static ILogger logger;
        public static ILoggerFactory loggerFactory;


    }
}