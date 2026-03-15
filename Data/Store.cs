using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Sezam.Data.EF;
using System;
using System.Collections.Concurrent;
using System.Linq;

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

            // Configure ConfTopic -> UserTopic relationship (filtered by current user)
            // Note: This is a reverse navigation - UserTopic references ConfTopic via TopicId
            modelBuilder.Entity<UserTopic>()
                .HasOne<ConfTopic>()
                .WithOne(t => t.UserTopic)
                .HasForeignKey<UserTopic>(ut => ut.TopicId)
                .HasPrincipalKey<ConfTopic>(t => t.Id)
                .IsRequired();

            // Configure self-referencing relationship for ConfTopic.RedirectTo
            modelBuilder.Entity<ConfTopic>()
                .HasOne(t => t.RedirectTo)
                .WithMany()
                .HasForeignKey(t => t.RedirectToId)
                .OnDelete(DeleteBehavior.Restrict);

            var userConfconverter = new EnumToNumberConverter<UserConf.UserConfStat, int>();
            modelBuilder.Entity<UserConf>()
                        .Property(e => e.Status)
                        .HasConversion(userConfconverter);

            modelBuilder.Entity<UserTopic>()
                .HasQueryFilter(ut => ut.UserId == UserId);

            // Configure Guid to BINARY(16) for MySQL
            modelBuilder.Entity<ConfMessage>()
                .Property(e => e.Id)
                .HasColumnType("binary(16)");

            modelBuilder.Entity<ConfMessage>()
                .Property(e => e.ParentMessageId)
                .HasColumnType("binary(16)");

            modelBuilder.Entity<MessageText>()
                .Property(e => e.Id)
                .HasColumnType("binary(16)");

            // Configure one-to-one relationship: ConfMessage.Id -> MessageText.Id
            // This enforces that every ConfMessage must have a corresponding MessageText
            modelBuilder.Entity<ConfMessage>()
                .HasOne(m => m.MessageText)
                .WithOne()
                .HasForeignKey<ConfMessage>(m => m.Id)
                .HasPrincipalKey<MessageText>(mt => mt.Id)
                .OnDelete(DeleteBehavior.Cascade);

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
        public DbSet<MessageText> MessageTexts { get; set; }
        public DbSet<UserConf> UserConfs { get; set; }
    }

    /// <summary>
    /// Design-time factory for Entity Framework migrations
    /// </summary>
    public class SezamDbContextFactory : Microsoft.EntityFrameworkCore.Design.IDesignTimeDbContextFactory<SezamDbContext>
    {
        public SezamDbContext CreateDbContext(string[] args)
        {
            // Read configuration from environment or use defaults
            var configuration = new ConfigurationBuilder()
                .AddJsonFile("appsettings.json", optional: true)
                .AddEnvironmentVariables()
                .Build();

            // Configure Store with connection string
            Store.ConfigureFrom(configuration);

            // Create options builder with configured connection string
            var optionsBuilder = new DbContextOptionsBuilder<SezamDbContext>();
            Store.GetOptionsBuilder(optionsBuilder);

            return new SezamDbContext(optionsBuilder.Options);
        }
    }

    public static class Store
    {
        public static void ConfigureFrom(IConfiguration configuration)
        {
            logger = LoggerFactory?.CreateLogger("Store") ?? NullLogger.Instance;
            // Database Configuration
            string DbHost = ResolveConfigValue(configuration, "DB_HOST", "DbHost");
            string DbName = ResolveConfigValue(configuration, "DB_NAME", "DbName") ?? "sezam";
            string Password = ResolveConfigValue(configuration, "DB_PASSWORD", "DbPassword");

            if (!string.IsNullOrEmpty(DbHost))
                DbConnectionString = $"server={DbHost};database={DbName};user=sezam;password={Password}";
            else
                DbConnectionString = ResolveConfigValue(configuration, "SezamDb", "Database", "Db");

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
                    logger?.LogInformation($"Resolved config value for '{name}': {(string.IsNullOrEmpty(value) ? "null" : value)}");
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

        /// <summary>
        /// Applies any pending database migrations.
        /// Call this at application startup to ensure the database schema is up to date.
        /// </summary>
        public static void ApplyMigrations()
        {
            using var context = GetNewContext();
            var pendingMigrations = context.Database.GetPendingMigrations().ToList();

            if (pendingMigrations.Count == 0)
            {
                logger?.LogDebug("Database is up to date.");
                return;
            }

            logger?.LogInformation("Applying {Count} pending migration(s): {Migrations}",
                    pendingMigrations.Count, string.Join(", ", pendingMigrations));
            try
            {
                context.Database.Migrate();
            }
            catch (Exception ex)
            {
                logger?.LogError(ex, "Error applying migrations.");
            }
            logger?.LogInformation("Database migrations applied successfully.");
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

        #region Messaging API

        /// <summary>
        /// Deliver a message to all local sessions. Does not publish to Redis.
        /// Use for node-local announcements (e.g. "shutting down").
        /// </summary>
        public static void LocalBroadcast(string fromUser, string message)
        {
            foreach (var s in Sessions.Values)
                s.Deliver(fromUser, message);
        }

        /// <summary>
        /// Deliver a message to all sessions on all nodes.
        /// Delivers locally first, then publishes to Redis for other nodes.
        /// </summary>
        public static void GlobalBroadcast(string fromUser, string message)
        {
            LocalBroadcast(fromUser, message);

            if (MessageBroadcaster is { IsRedisConnected: true })
            {
                var envelope = $"BROADCAST:{fromUser}:{message}";
                _ = MessageBroadcaster.BroadcastAsync(envelope);
            }
        }

        /// <summary>
        /// Send a message to a specific user by username.
        /// If the user is on this node, delivers directly (local shortcut).
        /// Otherwise publishes via Redis for the remote node to deliver.
        /// </summary>
        public static void SendToUser(string toUsername, string fromUser, string message)
        {
            // Local shortcut: find user on this node
            var localSession = Sessions.Values
                .FirstOrDefault(s => s.Username != null &&
                    s.Username.Equals(toUsername, StringComparison.OrdinalIgnoreCase));

            if (localSession != null)
            {
                localSession.Deliver(fromUser, message);
                return;
            }

            // Not local — send via Redis
            if (MessageBroadcaster is { IsRedisConnected: true })
            {
                var envelope = $"USER:{toUsername}:{fromUser}:{message}";
                _ = MessageBroadcaster.BroadcastAsync(envelope);
            }
            else
            {
                logger?.LogWarning("Cannot reach user {ToUser}: not local and Redis unavailable", toUsername);
            }
        }

        /// <summary>
        /// Send a message to a chat room on all nodes.
        /// Room "*" means public chat (all sessions).
        /// </summary>
        public static void SendToChat(string room, string fromUser, string message)
        {
            // Deliver to all local sessions (chat filtering is the receiver's concern)
            foreach (var s in Sessions.Values)
                s.Deliver(fromUser, $":chat:{room}:{message}");

            // Publish to Redis for other nodes
            if (MessageBroadcaster is { IsRedisConnected: true })
            {
                var envelope = $"CHAT:{room}:{fromUser}:{message}";
                _ = MessageBroadcaster.BroadcastAsync(envelope);
            }
        }

        #endregion

        // Database Configuration Properties
        public static string DbConnectionString { get; private set; }

        // Redis Configuration Properties
        public static string RedisConnectionString { get; private set; }
        // Redis is enabled if connection string is not empty            
        public static bool RedisEnabled => !RedisConnectionString.IsWhiteSpace();

        // Message Broadcaster Singleton
        public static MessageBroadcaster MessageBroadcaster { get; set; }

        public static ILogger logger;
        public static ILoggerFactory LoggerFactory;


    }
}