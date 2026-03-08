# Configuration Consolidation - What You Can Do Now

## 🚀 New Capabilities

Now that Redis and Database configuration is centralized in `Data/Store.cs`, you can:

### 1. Access Configuration Anywhere

```csharp
// In any command, service, or class
if (Store.RedisEnabled)
{
    Console.WriteLine($"Redis available at: {Store.RedisConnectionString}");
}

Console.WriteLine($"Database: {Store.ServerName}/{Store.DbName}");
```

### 2. Smart Deployment Configuration

**Instead of**:
```bash
# Old: Had to construct full strings
docker run \
  -e DB_CONNECTION_STRING="server=mysql;database=sezam;user=sezam;password=..." \
  -e REDIS_CONNECTION_STRING="redis:6379" \
  sezam:latest
```

**Now do**:
```bash
# New: Just provide the hosts
docker run \
  -e DB_HOST=mysql \
  -e REDIS_HOST=redis \
  sezam:latest
```

Ports and database names are inferred automatically! ✨

### 3. Flexible Configuration

**Option 1: Environment Variables** (Docker/Kubernetes)
```bash
DB_HOST=your-database
REDIS_HOST=your-redis
# All inferred automatically
```

**Option 2: Configuration File** (Local Development)
```json
{
  "ConnectionStrings": {
    "ServerName": "localhost",
    "Password": "password",
    "Redis": "localhost:6379"
  }
}
```

**Option 3: Mix Both**
```bash
# Environment variables override config file
DB_HOST=production-db     # Overrides appsettings
REDIS_HOST=production-redis  # Overrides appsettings
```

### 4. Graceful Redis Disabling

If Redis is not configured, everything still works:

```bash
# Just don't set REDIS_HOST and no "Redis" in config
# ✅ Database works normally
# ✅ MessageBroadcaster not created
# ✅ Session discovery disabled gracefully
# ✅ Local-only message mode
```

### 5. Conditional Features

In your commands:

```csharp
[Command("STATS")]
public async void ShowStats()
{
    await terminal.Line($"Database: {Store.ServerName}");
    
    if (Store.RedisEnabled)
    {
        // Show Redis-specific stats
        var remoteSessionCount = _registry.GetRemoteSessionCount();
        await terminal.Line($"Remote sessions: {remoteSessionCount}");
    }
    else
    {
        await terminal.Line("Redis: Disabled (local-only mode)");
    }
}
```

### 6. Multi-Environment Support

**Development**:
```json
{
  "ConnectionStrings": {
    "ServerName": "localhost",
    "Password": "dev_password",
    "Redis": "localhost:6379"
  }
}
```

**Staging**:
```bash
DB_HOST=staging-db.example.com
REDIS_HOST=staging-redis.example.com
```

**Production**:
```bash
DB_HOST=prod-db-cluster.example.com
REDIS_HOST=prod-redis-cluster.example.com
```

All work seamlessly with the same code! ✨

## 📋 Configuration Reference

### Available Properties

```csharp
// Database
Store.ServerName              // Database host
Store.DbName                  // Database name (default: "sezam")
Store.Password                // Database password

// Redis
Store.RedisConnectionString   // Redis host:port (e.g., "redis:6379")
Store.RedisEnabled            // bool - Is Redis configured?
```

### Configuration Sources

**Database**:
1. `DB_HOST` environment variable (highest priority)
2. `ServerName` in appsettings.json
3. Environment variable `DB_HOST` or `ConnectionStrings__ServerName`

**Redis**:
1. `REDIS_HOST` environment variable (highest priority)
2. `Redis` in appsettings.json ConnectionStrings
3. Environment variable `REDIS_HOST` or `ConnectionStrings__Redis`
4. Empty string = disabled (lowest priority)

## 🎯 Real-World Examples

### Example 1: Docker Compose

```yaml
version: '3.8'
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: sezam
      MYSQL_ROOT_PASSWORD: root_pass
    
  redis:
    image: redis:7-alpine
    
  sezam:
    build: .
    environment:
      DB_HOST: mysql              # Inferred ✨
      REDIS_HOST: redis           # Inferred ✨
      Password: root_pass         # Required
    ports:
      - "2023:2023"
    depends_on:
      - mysql
      - redis
```

### Example 2: Kubernetes

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sezam-config
data:
  DB_HOST: "mysql-service"
  REDIS_HOST: "redis-service"
  # Ports and database name inferred automatically! ✨
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sezam
spec:
  template:
    spec:
      containers:
      - name: sezam
        image: sezam:latest
        envFrom:
        - configMapRef:
            name: sezam-config
        env:
        - name: Password
          valueFrom:
            secretKeyRef:
              name: sezam-secrets
              key: db-password
```

### Example 3: Multiple Environments

```bash
# Development
dotnet run -p Telnet/Sezam.Telnet.csproj
# Uses: appsettings.json → localhost:3306, localhost:6379

# Staging
DB_HOST=staging-mysql REDIS_HOST=staging-redis dotnet run ...
# Uses: Environment vars → staging-mysql:3306, staging-redis:6379

# Production
DB_HOST=prod-db-cluster.rds.amazonaws.com \
REDIS_HOST=prod-redis-cluster.elasticache.amazonaws.com \
  dotnet run ...
# Uses: Environment vars → AWS RDS, AWS ElastiCache
```

### Example 4: Minimal Configuration (Redis Disabled)

```json
{
  "ConnectionStrings": {
    "ServerName": "localhost",
    "Password": "password"
    // No Redis = disabled
  }
}
```

Result:
- ✅ Database works
- ✅ No message broadcasting (local-only)
- ✅ No session discovery (local-only)
- ✅ System runs perfectly fine

## 🔄 Migration from Old Configuration

### Old appsettings.json
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

### New appsettings.json
```json
{
  "ConnectionStrings": {
    "ServerName": "tux.zakic.net",
    "Password": "sandbox#",
    "Redis": "localhost:6379"
  }
}
```

**Both formats work!** ✨ The new code is backward compatible.

## 💡 Best Practices

### 1. Use Environment Variables in Production
```bash
DB_HOST=production-db
REDIS_HOST=production-redis
Password=strong-password-here
```

Reason: Easier to manage, less configuration files to track

### 2. Use appsettings.json in Development
```json
{
  "ConnectionStrings": {
    "ServerName": "localhost",
    "Password": "dev-password",
    "Redis": "localhost:6379"
  }
}
```

Reason: Easier to set up locally, less env vars to manage

### 3. Check Redis Status in Code
```csharp
if (Store.RedisEnabled)
{
    // Use Redis-specific features
}
else
{
    // Graceful degradation
}
```

### 4. Use Simple Host Names
```bash
# ✅ Good
DB_HOST=mysql
REDIS_HOST=redis

# ✅ Also good
DB_HOST=mysql.example.com
REDIS_HOST=redis.example.com

# ✅ Works but verbose
DB_HOST=mysql.example.com:3306
REDIS_HOST=redis.example.com:6379
```

## 📊 Deployment Comparison

### Before Consolidation
- Configuration scattered across 4 locations
- Duplicate config logic
- Different behavior between Telnet and Web
- Full connection strings needed
- Extra env vars (e.g., `REDIS_HOST` only checked in Web!)

### After Consolidation
- Single source of truth
- Consistent behavior everywhere
- Smart host inference
- Simple environment variables
- Unified across all projects

## 🎯 Key Takeaways

✅ **Smart**: Infer connection strings from hosts
✅ **Centralized**: All config in one place
✅ **Flexible**: Env vars or config files
✅ **Graceful**: Redis disabled automatically if not configured
✅ **Consistent**: Same behavior across all projects
✅ **Compatible**: Backward compatible with existing configs

---

## 📚 See Also

- `README_CONSOLIDATION_COMPLETE.md` - Implementation complete summary
- `CONFIGURATION_CONSOLIDATION_QUICKREF.md` - Quick reference
- `Doc/REDIS_CONFIGURATION_CONSOLIDATION_COMPLETE.md` - Detailed guide
- `Data/Store.cs` - Source code with comments

---

**You're all set!** Your configuration is now centralized, smart, and production-ready. 🚀
