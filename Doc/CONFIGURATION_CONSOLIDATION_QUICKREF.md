# Configuration Consolidation - Quick Reference

## What Changed?

Redis configuration has been moved from 4 scattered locations to 1 centralized location in `Data/Store.cs`, with smart host-based configuration inference.

## Configuration Priority (Highest to Lowest)

### Database
1. `DB_HOST` environment variable → inferred to MySQL connection string
2. `ServerName` in appsettings.json ConnectionStrings
3. Falls back if not configured

### Redis
1. `REDIS_HOST` environment variable → inferred to `{host}:6379`
2. `Redis` in appsettings.json ConnectionStrings
3. Falls back to empty (Redis disabled)

## How to Use

### Local Development
```bash
# Uses appsettings.json values (no env vars needed)
dotnet run -p Telnet/Sezam.Telnet.csproj
```

### Docker Compose
```bash
docker-compose up -d
# Uses REDIS_HOST=redis, DB_HOST=mysql from docker-compose
```

### Kubernetes
```yaml
env:
  - name: DB_HOST
    value: "mysql-service"
  - name: REDIS_HOST
    value: "redis-service"
```

### Disable Redis
```json
{
  "ConnectionStrings": {
    "ServerName": "localhost",
    "Password": "password"
    // Omit or leave empty "Redis" key
  }
}
```

## Environment Variables

### Database
```bash
DB_HOST=localhost              # Inferred to MySQL connection
ServerName=localhost           # Fallback
Password=secure_password       # Required
```

### Redis
```bash
REDIS_HOST=redis              # Inferred to redis:6379
# Redis=redis:6379           # Fallback (ConnectionStrings config)
```

## appsettings.json Format

```json
{
  "ConnectionStrings": {
    "ServerName": "localhost",
    "Password": "password",
    "Redis": "localhost:6379"
  }
}
```

## Code Access

```csharp
// In any C# file
Store.RedisConnectionString  // Get Redis connection string
Store.RedisEnabled           // Check if Redis is enabled
Store.ServerName             // Get database server
Store.DbName                 // Get database name
Store.Password               // Get database password
```

## Files Modified

1. `Data/Store.cs` - Added Redis properties, smart host inference
2. `Console/Server.cs` - Simplified to use Store.RedisConnectionString
3. `Web/Startup.cs` - Simplified to use Store.RedisConnectionString
4. `Telnet/appsettings.json` - Redis moved to ConnectionStrings
5. `Web/appsettings.json` - Redis moved to ConnectionStrings

## Build Status

✅ **Build Successful**

All changes compile without errors and are fully backward compatible.

## Key Features

✨ **Smart Host Inference**
- Set `REDIS_HOST=redis` → automatically becomes `redis:6379`
- Set `DB_HOST=mysql` → automatically becomes `server=mysql;database=sezam;...`

✨ **Centralized Configuration**
- Both database and Redis config in one place
- Single source of truth
- Easy to modify defaults

✨ **Graceful Disabling**
- Redis automatically disabled if connection string is empty
- No extra boolean configuration needed
- MessageBroadcaster only created if enabled

✨ **Backward Compatible**
- Still reads from appsettings.json
- Still reads from environment variables
- Legacy configurations still work

---

See full details in: `Doc/REDIS_CONFIGURATION_CONSOLIDATION_COMPLETE.md`
