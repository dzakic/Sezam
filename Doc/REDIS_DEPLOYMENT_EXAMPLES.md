# Redis Configuration Examples

## Local Development (No Redis)

**appsettings.json**
```json
{
  "Redis": {
    "ConnectionString": ""
  }
}
```

Or omit the Redis section entirely. The system will default to `localhost:6379` but will gracefully fall back when it's unavailable.

**Result**: Messages stay local to each terminal session.

---

## Local Development with Redis

**Start Redis**
```bash
docker run -d -p 6379:6379 --name sezam-redis redis:7-alpine
```

**appsettings.json**
```json
{
  "Redis": {
    "ConnectionString": "localhost:6379"
  }
}
```

**Result**: Messages broadcast to other local sessions via Redis.

---

## Docker Compose Multi-Node

**docker-compose.yml**
```yaml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - sezam-network

  sezam-telnet-1:
    build:
      context: .
      dockerfile: Dockerfile
      target: runtime
    environment:
      - REDIS_CONNECTION_STRING=redis:6379
      - ServerName=sezam.local
      - Password=sandbox#
    ports:
      - "2023:2023"
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - sezam-network

  sezam-telnet-2:
    build:
      context: .
      dockerfile: Dockerfile
      target: runtime
    environment:
      - REDIS_CONNECTION_STRING=redis:6379
      - ServerName=sezam.local
      - Password=sandbox#
    ports:
      - "2024:2023"
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - sezam-network

networks:
  sezam-network:
    driver: bridge
```

**Usage**
```bash
docker-compose up -d

# Connect to node 1
telnet localhost 2023

# Connect to node 2 in another terminal
telnet localhost 2024

# Messages sent in node 1 will appear in node 2
```

---

## Kubernetes Deployment

**deployment.yaml** (updated with Redis init)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
  clusterIP: None

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"

---

apiVersion: v1
kind: Service
metadata:
  name: sezam-telnet
spec:
  type: LoadBalancer
  selector:
    app: sezam-telnet
  ports:
    - port: 2023
      targetPort: 2023

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: sezam-telnet
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sezam-telnet
  template:
    metadata:
      labels:
        app: sezam-telnet
    spec:
      containers:
      - name: sezam-telnet
        image: sezam:latest
        ports:
        - containerPort: 2023
        env:
        - name: REDIS_CONNECTION_STRING
          value: "redis:6379"
        - name: ServerName
          value: "sezam.example.com"
        - name: Password
          valueFrom:
            secretKeyRef:
              name: sezam-secrets
              key: password
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

**Usage**
```bash
kubectl apply -f deployment.yaml

# Check status
kubectl get pods -l app=sezam-telnet
kubectl get pods -l app=redis

# Connect to service
kubectl port-forward svc/sezam-telnet 2023:2023

# In another terminal
telnet localhost 2023
```

---

## Azure Container Instances with Redis

**docker-compose-azure.yml**
```yaml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  sezam-telnet:
    image: sezam:latest
    environment:
      - REDIS_CONNECTION_STRING=redis:6379
      - ServerName=sezam-azure.example.com
      - Password=${SEZAM_PASSWORD}
    ports:
      - "2023:2023"
    depends_on:
      - redis
```

**Deploy**
```bash
az container create \
  --resource-group myGroup \
  --name sezam-aci \
  --image myregistry.azurecr.io/sezam:latest \
  --environment-variables \
    REDIS_CONNECTION_STRING=redis:6379 \
    ServerName=sezam-azure.example.com \
  --ports 2023
```

---

## AWS ECS / Fargate with ElastiCache

**task-definition.json** (simplified)
```json
{
  "family": "sezam-telnet",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "sezam-telnet",
      "image": "123456789.dkr.ecr.us-east-1.amazonaws.com/sezam:latest",
      "portMappings": [
        {
          "containerPort": 2023,
          "hostPort": 2023
        }
      ],
      "environment": [
        {
          "name": "REDIS_CONNECTION_STRING",
          "value": "sezam-redis.abc123.ng.0001.use1.cache.amazonaws.com:6379"
        },
        {
          "name": "ServerName",
          "value": "sezam-aws.example.com"
        }
      ]
    }
  ]
}
```

---

## Fallback Scenario (No Redis Available)

If Redis is unavailable for any reason:

**Environment Variable Not Set**
```bash
# No REDIS_CONNECTION_STRING env var
dotnet run
# System logs: "Redis connection failed: Connection refused"
# System continues in local-only mode
```

**Configuration Disabled**
```json
{
  "Redis": {
    "ConnectionString": ""
  }
}
```

**Result**: Both scenarios work identically - messages broadcast only within the local session, no errors thrown.

---

## Monitoring Redis Connection

**Health Check Endpoint** (optional enhancement)
```csharp
app.MapGet("/health/redis", (MessageBroadcaster broadcaster) =>
{
    return new 
    { 
        status = broadcaster.IsRedisConnected ? "connected" : "disconnected",
        mode = broadcaster.IsRedisConnected ? "distributed" : "local"
    };
});
```

**Kubernetes Health Check**
```yaml
livenessProbe:
  httpGet:
    path: /health/redis
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 30
```

---

## Performance Notes

- **Local Mode**: Zero network overhead
- **Redis Mode**: ~1-2ms per broadcast (network dependent)
- **Redis Memory**: ~1KB per subscriber connection
- **Recommended Redis Version**: 6.0+
- **Redis Persistence**: Optional (messages are transient, no durability needed)

---

## Troubleshooting

### Messages not appearing across nodes
1. Check Redis is running: `redis-cli ping` → should return `PONG`
2. Check connection string: `REDIS_CONNECTION_STRING` or config
3. Check firewall: Port 6379 must be open between nodes and Redis
4. Check logs: Look for "Redis connection failed" messages

### High Redis memory usage
- Check for subscription leaks (terminals not cleaning up)
- Monitor `CLIENT LIST` in Redis CLI
- Restart Redis if needed (transient data, no persistence required)

### Latency between nodes
- Use `redis-cli --latency` to measure network latency
- Consider Redis closer to deployment (same datacenter/AZ)
- Use connection pooling if implementing additional features
