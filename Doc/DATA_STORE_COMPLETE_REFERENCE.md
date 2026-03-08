# Data.Store Complete Reference

## Overview

`Data.Store` is the centralized singleton for all global application configuration and services.

## Complete Property Listing

### Database Configuration

```csharp
public static string ServerName { get; private set; }
// Database host (e.g., "localhost", "mysql.example.com")
// Source: DB_HOST env var → ServerName config → required
```

```csharp
public static string Password { get; private set; }
// Database password
// Source: Password env var → Password config → required
```

```csharp
public static string DbName { get; private set; }
// Database name (e.g., "sezam")
// Source: DbName config → default: "sezam"
```

### Redis Configuration

```csharp
public static string RedisConnectionString { get; private set; }
// Redis connection string (e.g., "localhost:6379")
// Source: REDIS_HOST env var (inferred) → Redis config → null if disabled
```

```csharp
public static bool RedisEnabled { get; private set; }
// Whether Redis is configured and available
// Automatically set based on RedisConnectionString
// Auto-true if RedisConnectionString is non-empty
```

### Global Services

```csharp
public static dynamic MessageBroadcaster { get; set; }
// Singleton MessageBroadcaster instance for distributed messaging
// Initialized in Server.InitializeAsync() if RedisEnabled
// Null if Redis not configured
```

```csharp
public static readonly ConcurrentDictionary<Guid, ISession> Sessions
// All active sessions (local and tracked)
// Thread-safe dictionary of all connected users
// Managed by AddSession() and RemoveSession()
```

## Methods

### Configuration

```csharp
public static void ConfigureFrom(IConfiguration configuration)
// Read all configuration from IConfiguration (environment + appsettings.json)
// Priority: Environment variables → Config file → Defaults
// Sets all properties above
// Called once at startup from Server or Web startup
```

```csharp
public static string ResolveConfigValue(IConfiguration configuration, string name)
// Resolve a single config value with priority:
// 1. Environment variable named 'name'
// 2. Environment variable named 'ConnectionStrings__name'
// 3. configuration.GetConnectionString(name)
// 4. configuration["ConnectionStrings:name"]
// 5. configuration[name]
// 6. null (default)
```

### Database

```csharp
public static DbContextOptionsBuilder GetOptionsBuilder(DbContextOptionsBuilder builder)
// Configure Entity Framework with database connection options
// Returns configured options builder ready for DbContext creation
// Uses ServerName, DbName, Password to build MySQL connection string
```

```csharp
public static SezamDbContext GetNewContext()
// Create a new database context instance
// Uses GetOptionsBuilder() to configure options
// Returns ready-to-use DbContext scoped with current user
```

### Session Management

```csharp
public static void AddSession(ISession session)
// Add a session to the global Sessions dictionary
// Called when user connects
// Thread-safe (uses ConcurrentDictionary)
```

```csharp
public static void RemoveSession(ISession session)
// Remove a session from the global Sessions dictionary
// Called when user disconnects
// Thread-safe (uses ConcurrentDictionary)
```

## Configuration Priority Order

### Database (ServerName)
```
1. DB_HOST environment variable (highest priority)
   └─ Inferred to MySQL connection string
   
2. ServerName in config file
   └─ appsettings.json ConnectionStrings:ServerName
   
3. Fallback if not configured
   └─ Must be set somewhere or DB connection fails
```

### Database (Password)
```
1. Password environment variable
   └─ appsettings.json ConnectionStrings:Password
   
2. Must be set in one of the above sources
```

### Redis (Connection String)
```
1. REDIS_HOST environment variable (highest priority)
   └─ Inferred to "host:6379" automatically
   
2. Redis in config file
   └─ appsettings.json ConnectionStrings:Redis
   
3. Empty/null = Redis disabled
   └─ All features degrade gracefully
```

## Usage Examples

### Basic Access

```csharp
// Check if Redis is available
if (Store.RedisEnabled)
{
    var redis = Store.RedisConnectionString;  // "localhost:6379"
}

// Get database info
var db = Store.ServerName;      // "localhost"
var dbName = Store.DbName;      // "sezam"

// Get all sessions
var sessionCount = Store.Sessions.Count;
```

### Message Broadcasting

```csharp
// From any class
if (Store.MessageBroadcaster != null)
{
    await Store.MessageBroadcaster.BroadcastAsync("message");
}
```

### Session Management

```csharp
// Add new session
var session = new Session(terminal);
Store.AddSession(session);

// Get session by ID
var session = Store.Sessions[sessionId];

// Iterate all sessions
foreach (var sess in Store.Sessions.Values)
{
    Console.WriteLine(sess.Username);
}

// Remove session
Store.RemoveSession(session);
```

### Database Access

```csharp
// Create new context
using var db = Store.GetNewContext();
var users = await db.Users.ToListAsync();

// Build EF options
var options = Store.GetOptionsBuilder(new DbContextOptionsBuilder());
```

## Multi-Tenant Isolation

Database context scoping with query filters:

```csharp
// In Session class
Db.UserId = user.Id;  // Set current user
Db.SaveChangesAsync();  // Queries automatically filtered by user
```

Query filters in `SezamDbContext.OnModelCreating()`:
```csharp
modelBuilder.Entity<UserConf>()
    .HasQueryFilter(uc => uc.UserId == UserId);  // Auto-filters by UserId
```

## Thread Safety

```csharp
// Sessions is thread-safe
public static readonly ConcurrentDictionary<Guid, ISession> Sessions = new();

// Configuration properties are read-only after initialization
public static string ServerName { get; private set; }  // Set once in ConfigureFrom()

// MessageBroadcaster is set once during initialization
public static dynamic MessageBroadcaster { get; set; }  // Set in InitializeAsync()
```

## Initialization Sequence

```
1. Web/Startup.ConfigureServices()
   └─ or Server constructor

2. Store.ConfigureFrom(configuration)
   └─ Reads environment variables and appsettings.json
   └─ Sets ServerName, Password, DbName, RedisConnectionString, RedisEnabled

3. Server.InitializeAsync()
   └─ If RedisEnabled:
      ├─ Create new MessageBroadcaster()
      └─ Store in Store.MessageBroadcaster
      └─ Initialize with RedisConnectionString

4. Ready to use
   └─ Sessions can be added/removed
   └─ Broadcaster available for messaging
```

## Configuration Examples

### Development Environment

```json
{
  "ConnectionStrings": {
    "ServerName": "localhost",
    "Password": "dev_password",
    "Redis": "localhost:6379"
  }
}
```

Resulting properties:
- `Store.ServerName` = "localhost"
- `Store.DbName` = "sezam" (default)
- `Store.RedisConnectionString` = "localhost:6379"
- `Store.RedisEnabled` = true
- `Store.MessageBroadcaster` = MessageBroadcaster instance

### Docker Environment

```bash
DB_HOST=mysql
REDIS_HOST=redis
Password=docker_password
```

Resulting properties:
- `Store.ServerName` = "mysql"
- `Store.DbName` = "sezam" (default)
- `Store.RedisConnectionString` = "redis:6379" (inferred)
- `Store.RedisEnabled` = true
- `Store.MessageBroadcaster` = MessageBroadcaster instance

### Redis Disabled

```json
{
  "ConnectionStrings": {
    "ServerName": "localhost",
    "Password": "password"
  }
}
```

Resulting properties:
- `Store.ServerName` = "localhost"
- `Store.DbName` = "sezam" (default)
- `Store.RedisConnectionString` = null or empty
- `Store.RedisEnabled` = false
- `Store.MessageBroadcaster` = null

## Error Handling

```csharp
// Graceful degradation if Redis not available
if (Store.RedisEnabled && Store.MessageBroadcaster != null)
{
    try
    {
        await Store.MessageBroadcaster.BroadcastAsync("message");
    }
    catch (Exception ex)
    {
        Debug.WriteLine($"Broadcast failed: {ex.Message}");
        // Continue - messages stay local only
    }
}
```

## Testing and Mocking

```csharp
// In unit tests
[SetUp]
public void Setup()
{
    // Reset configuration
    var config = new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string>
        {
            { "ConnectionStrings:ServerName", "test-db" },
            { "ConnectionStrings:Password", "test" }
        })
        .Build();
    
    Store.ConfigureFrom(config);
    
    // Mock broadcaster
    Store.MessageBroadcaster = new MockMessageBroadcaster();
}
```

## Best Practices

### ✅ DO
```csharp
// Check before accessing
if (Store.MessageBroadcaster != null)
{
    // Use broadcaster
}

// Use Store properties directly
var server = Store.ServerName;

// Thread-safe session access
var session = Store.Sessions[id];
```

### ❌ DON'T
```csharp
// Don't cache Store values
var server = Store.ServerName;
var cached = server;  // Don't do this, use Store.ServerName directly

// Don't create multiple DbContexts without reason
for (var i = 0; i < 100; i++)
{
    using var db = Store.GetNewContext();  // Creates new context each time
}

// Don't assume broadcaster is always initialized
var broadcaster = Store.MessageBroadcaster;  // Could be null
```

---

**Data.Store** is your single source of truth for all global application state! ✨
