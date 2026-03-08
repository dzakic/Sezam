# Redis Configuration Research & Analysis

## Current State

### Database Configuration (Centralized in Data.Store)

**Location**: `Data/Store.cs`

```csharp
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

    // Static properties for easy access
    public static string ServerName { get; private set; }
    public static string Password { get; private set; }
    public static string DbName { get; private set; }
}
```

**Key Characteristics**:
- ✅ Centralized configuration
- ✅ Configuration priority: env var → env connection string → config file
- ✅ Static properties for application-wide access
- ✅ Helper method to build connection strings
- ✅ Used by multiple projects (Console, Web, Telnet)

---

### Redis Configuration (Currently Scattered)

#### Location 1: Server.cs (Telnet/Console)

```csharp
public async Task InitializeAsync()
{
    messageBroadcaster = new MessageBroadcaster();
    var redisConnectionString = configuration?["Redis:ConnectionString"] 
        ?? Environment.GetEnvironmentVariable("REDIS_CONNECTION_STRING")
        ?? "localhost:6379";
    await messageBroadcaster.InitializeAsync(redisConnectionString);
}
```

**Issues**:
- ❌ Configuration lookup duplicated
- ❌ Hard to change defaults
- ❌ Logic repeated in Web/Startup.cs

#### Location 2: Web/Startup.cs

```csharp
services.AddSingleton<MessageBroadcaster>(sp => 
{
    var broadcaster = new MessageBroadcaster();
    var redisConnectionString = Configuration?["Redis:ConnectionString"] 
        ?? Environment.GetEnvironmentVariable("REDIS_CONNECTION_STRING")
        ?? Environment.GetEnvironmentVariable("REDIS_HOST") + ":6379"  // Extra env var check
        ?? "localhost:6379";
    broadcaster.InitializeAsync(redisConnectionString).GetAwaiter().GetResult();
    return broadcaster;
});
```

**Issues**:
- ❌ Different fallback logic than Server.cs
- ❌ Checks `REDIS_HOST` (not consistent)
- ❌ Duplicated from Server.cs

#### Location 3: appsettings.json Files

**Telnet/appsettings.json**:
```json
{
  "ConnectionStrings": {
    "ServerName": "tux.zakic.net",
    "Password": "sandbox#"
  },
  "Redis": {
    "ConnectionString": "localhost:6379"
  }
}
```

**Web/appsettings.json**:
```json
{
  "ConnectionStrings": {
    "ServerName": "tux.zakic.net",
    "Password": "sandbox#"
  },
  "Redis": {
    "ConnectionString": "localhost:6379"
  },
  "Logging": {...}
}
```

**Issues**:
- ❌ Separate Redis configuration section
- ❌ Not co-located with other connection strings
- ❌ Duplicated in both appsettings files

---

## Configuration Flow Comparison

### Database Configuration Flow

```
appsettings.json
    ↓
Store.ConfigureFrom(IConfiguration)
    ↓
Store.ServerName     ← Static property
Store.Password       ← Static property
Store.DbName         ← Static property
    ↓
Store.GetOptionsBuilder()
    ↓
Used everywhere:
  - Server (Telnet)
  - Web (Startup)
  - Console (RunConsoleSession)
```

### Current Redis Configuration Flow

```
Telnet/appsettings.json          Web/appsettings.json
    ↓                                 ↓
Server.InitializeAsync()         Web/Startup.ConfigureServices()
    ↓                                 ↓
Configuration lookup             Configuration lookup (different!)
    ↓                                 ↓
MessageBroadcaster.InitializeAsync()
    ↓
No static properties
No reusability
```

---

## Issues Found

### 1. **Configuration Logic Duplication**
- Server.cs has one fallback order
- Web/Startup.cs has different fallback order
- No single source of truth

### 2. **Inconsistent Environment Variable Naming**
- Server.cs: `REDIS_CONNECTION_STRING`
- Web/Startup.cs: `REDIS_CONNECTION_STRING` + `REDIS_HOST`
- Not standardized

### 3. **Configuration Not Co-Located**
- Database config: `ConnectionStrings` section
- Redis config: `Redis` section (separate)
- Not following same pattern

### 4. **No Static Properties for Redis**
- Database: `Store.ServerName`, `Store.Password` (reusable)
- Redis: Created on-demand in two places
- Can't access Redis config from other parts of code

### 5. **Different Initialization Patterns**
- Database: `Store.GetNewContext()` (factory pattern)
- Redis: Singleton registered in DI (reactive)
- Inconsistent approach

### 6. **Hard to Change Defaults**
- Telnet default: `"localhost:6379"`
- Web default: `"localhost:6379"` (but also checks `REDIS_HOST`)
- Scattered across two files

---

## Proposed Consolidation

### Option 1: Add to Data.Store (Recommended)

Move Redis configuration to `Data/Store.cs` just like database config:

```csharp
public static class Store
{
    // Existing DB config
    public static string ServerName { get; private set; }
    public static string Password { get; private set; }
    public static string DbName { get; private set; }
    
    // NEW: Redis config
    public static string RedisConnectionString { get; private set; }
    public static bool RedisEnabled { get; private set; }

    public static void ConfigureFrom(IConfiguration configuration)
    {
        // Existing DB config
        DbName = ResolveConfigValue(configuration, "DbName") ?? "sezam";
        ServerName = ResolveConfigValue(configuration, "ServerName");
        Password = ResolveConfigValue(configuration, "Password");
        
        // NEW: Redis config
        RedisConnectionString = ResolveConfigValue(configuration, "Redis:ConnectionString") 
            ?? ResolveConfigValue(configuration, "REDIS_CONNECTION_STRING")
            ?? "localhost:6379";
        RedisEnabled = !string.IsNullOrWhiteSpace(RedisConnectionString);
    }
}
```

**Advantages**:
- ✅ Single source of truth
- ✅ Consistent with DB config pattern
- ✅ Easy to access from anywhere (`Store.RedisConnectionString`)
- ✅ Centralized fallback logic
- ✅ Easy to extend with Redis pool size, timeout, etc.

### Option 2: Create RedisStore Class (Also Good)

Separate Redis configuration into its own module:

```csharp
// Data/RedisStore.cs
public static class RedisStore
{
    public static string ConnectionString { get; private set; }
    public static int ConnectTimeout { get; private set; } = 2000;
    public static int SyncTimeout { get; private set; } = 2000;
    public static bool Enabled { get; private set; }

    public static void ConfigureFrom(IConfiguration configuration)
    {
        ConnectionString = ResolveConfigValue(configuration, "Redis:ConnectionString")
            ?? Environment.GetEnvironmentVariable("REDIS_CONNECTION_STRING")
            ?? "localhost:6379";
        
        Enabled = !string.IsNullOrWhiteSpace(ConnectionString);
    }
}
```

**Advantages**:
- ✅ Separation of concerns
- ✅ Extensible for Redis-specific options
- ✅ Parallel to Store.cs pattern
- ❌ Creates another module (slight duplication)

---

## Configuration File Changes

### Current appsettings.json

```json
{
  "ConnectionStrings": {
    "ServerName": "tux.zakic.net",
    "Password": "sandbox#"
  },
  "Redis": {
    "ConnectionString": "localhost:6379"
  }
}
```

### Proposed appsettings.json (Option A: Keep Separate)

```json
{
  "ConnectionStrings": {
    "ServerName": "tux.zakic.net",
    "Password": "sandbox#",
    "RedisConnectionString": "localhost:6379"
  }
}
```

**Advantage**: All connections in one place, more consistent

### Proposed appsettings.json (Option B: Keep Redis Separate)

```json
{
  "ConnectionStrings": {
    "ServerName": "tux.zakic.net",
    "Password": "sandbox#"
  },
  "Redis": {
    "ConnectionString": "localhost:6379",
    "ConnectTimeout": 2000,
    "SyncTimeout": 2000
  }
}
```

**Advantage**: Room for Redis-specific options (timeouts, pool size, etc.)

---

## Usage Comparison

### Current Usage

```csharp
// Server.cs
var redisConnectionString = configuration?["Redis:ConnectionString"] 
    ?? Environment.GetEnvironmentVariable("REDIS_CONNECTION_STRING")
    ?? "localhost:6379";
await messageBroadcaster.InitializeAsync(redisConnectionString);

// Web/Startup.cs
var redisConnectionString = Configuration?["Redis:ConnectionString"] 
    ?? Environment.GetEnvironmentVariable("REDIS_CONNECTION_STRING")
    ?? Environment.GetEnvironmentVariable("REDIS_HOST") + ":6379"
    ?? "localhost:6379";
broadcaster.InitializeAsync(redisConnectionString).GetAwaiter().GetResult();
```

### Proposed Usage (In Store.cs)

```csharp
// Initialization (done once at startup)
public static void ConfigureFrom(IConfiguration configuration)
{
    // ... existing DB config ...
    
    RedisConnectionString = ResolveConfigValue(configuration, "Redis:ConnectionString") 
        ?? "localhost:6379";
    RedisEnabled = !string.IsNullOrWhiteSpace(RedisConnectionString);
}
```

### Proposed Usage (In Server.cs)

```csharp
public async Task InitializeAsync()
{
    messageBroadcaster = new MessageBroadcaster();
    await messageBroadcaster.InitializeAsync(Store.RedisConnectionString);
    // Clean, simple, consistent
}
```

### Proposed Usage (In Web/Startup.cs)

```csharp
services.AddSingleton<MessageBroadcaster>(sp => 
{
    var broadcaster = new MessageBroadcaster();
    broadcaster.InitializeAsync(Store.RedisConnectionString).GetAwaiter().GetResult();
    return broadcaster;
});
```

---

## Environment Variable Priority

### Current (Inconsistent)

**Server.cs**:
1. `configuration["Redis:ConnectionString"]`
2. `REDIS_CONNECTION_STRING`
3. `"localhost:6379"`

**Web/Startup.cs**:
1. `Configuration["Redis:ConnectionString"]`
2. `REDIS_CONNECTION_STRING`
3. `REDIS_HOST` (only in Web!)
4. `"localhost:6379"`

### Proposed (Unified)

```csharp
RedisConnectionString = 
    Environment.GetEnvironmentVariable("REDIS_CONNECTION_STRING")  // Highest priority
    ?? configuration?.GetConnectionString("Redis:ConnectionString") // Config file
    ?? configuration?["Redis:ConnectionString"]                      // Alternative config
    ?? "localhost:6379";                                             // Default
```

**Benefits**:
- Follows same pattern as DB config
- Environment vars override config file
- Single point of management
- Clear precedence

---

## Files Affected by Consolidation

### Changes Required

1. **Data/Store.cs**
   - Add `RedisConnectionString` property
   - Add `RedisEnabled` property
   - Add Redis config to `ConfigureFrom()`
   - Update `ResolveConfigValue()` if needed

2. **Console/Server.cs**
   - Remove Redis config lookup
   - Use `Store.RedisConnectionString`
   - Simplify `InitializeAsync()`

3. **Web/Startup.cs**
   - Remove Redis config lookup
   - Use `Store.RedisConnectionString`
   - Simplify broadcaster registration

4. **appsettings.json** (both Telnet and Web)
   - Move Redis config to ConnectionStrings section (Option A)
   - OR keep separate but cleaner (Option B)

### No Changes Required

- `Console/Messaging/MessageBroadcaster.cs` - Just receives connection string
- `Console/Session.cs` - No config involved
- `Console/Messaging/SessionInfo.cs` - No config involved
- `Console/Messaging/DistributedSessionRegistry.cs` - No config involved
- Telnet/TelnetHostedService.cs - Already uses Server

---

## Benefits of Consolidation

| Aspect | Current | After Consolidation |
|--------|---------|---------------------|
| Configuration Locations | 2 files | 1 file |
| Environment Variable Logic | Duplicated | Centralized |
| Default Values | Scattered | Single source |
| Static Access | N/A | `Store.RedisConnectionString` |
| Configuration Priority | Inconsistent | Consistent |
| Code Reusability | Limited | Full |
| Maintenance Burden | Higher | Lower |
| Consistency | Low | High |

---

## Risk Assessment

### Low Risk
- ✅ No business logic changes
- ✅ No database schema changes
- ✅ No behavior changes
- ✅ Only refactoring configuration
- ✅ Backward compatible (same final result)

### Affected Components
- Store.cs (add properties)
- Server.cs (simplify)
- Startup.cs (simplify)
- appsettings.json (reorganize)

### Testing Requirements
- Verify Redis connection with config file
- Verify Redis connection with environment variable
- Verify default connection
- Verify both Telnet and Web work
- Verify fallback to local-only mode

---

## Recommended Approach

**Option: Consolidate in Data.Store.cs**

**Reasoning**:
1. Follows existing pattern perfectly
2. Single point of configuration (like DB)
3. Easy to access (`Store.RedisConnectionString`)
4. Extensible for future Redis options
5. Minimal code changes
6. High maintainability

**Implementation Steps**:
1. Add properties to `Store.cs`
2. Add Redis config to `ConfigureFrom()` method
3. Update `Server.cs` to use `Store.RedisConnectionString`
4. Update `Web/Startup.cs` to use `Store.RedisConnectionString`
5. Update appsettings.json (move Redis to ConnectionStrings)
6. Test all scenarios

---

## Checklist for Consolidation

- [ ] Review Store.cs structure
- [ ] Decide config file reorganization (ConnectionStrings vs separate)
- [ ] Add Redis properties to Store.cs
- [ ] Update Store.ConfigureFrom()
- [ ] Update Server.cs InitializeAsync()
- [ ] Update Web/Startup.cs ConfigureServices()
- [ ] Update appsettings.json files
- [ ] Test local-only mode
- [ ] Test with Redis
- [ ] Test environment variable override
- [ ] Verify both Telnet and Web work
- [ ] Update documentation

---

## Notes

- **Configuration values are case-sensitive** in JSON
- **Environment variables are case-sensitive** on Linux, not on Windows
- **ResolveConfigValue** already handles multiple sources - perfect pattern to follow
- **Current defaults are reasonable** - `localhost:6379` is standard Redis port
- **No breaking changes** - this is pure refactoring

---

**Conclusion**: Consolidating Redis configuration into `Data.Store.cs` would significantly improve code consistency, maintainability, and reduce configuration scatter. The pattern already exists for database configuration and should be applied uniformly to Redis.
