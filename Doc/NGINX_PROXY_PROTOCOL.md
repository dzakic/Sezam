# NGINX Stream PROXY Protocol Configuration

This document explains how to configure NGINX stream proxy to forward Telnet traffic to Sezam with the HAProxy PROXY protocol enabled, allowing Sezam to identify the real remote IP address of connecting users.

---

## 1. NGINX Stream Proxy Configuration

In your `nginx.conf` (or `/etc/nginx/stream.d/telnet.conf`), define a `stream` block:

```nginx
stream {
    upstream sezam_telnet {
        # Docker Swarm service name or container host and port
        server tel:2023;
    }

    server {
        listen 2023;

        # Forward TCP connection to Sezam backend
        proxy_pass sezam_telnet;

        # Enable PROXY protocol (v1 text by default)
        proxy_protocol on;

        # Optional: adjust connection timeouts for interactive telnet sessions
        proxy_timeout 1h;
        proxy_connect_timeout 5s;
    }
}
```

> [!NOTE]
> The `proxy_protocol on;` directive transmits the HAProxy PROXY protocol v1 header immediately after establishing the upstream TCP connection:
> `PROXY TCP4 <client_ip> <proxy_ip> <client_port> 2023\r\n`
> Sezam intercepts this header, extracts `<client_ip>`, and strips the header from the stream so subsequent Telnet negotiation and user input proceed seamlessly.

---

## 2. Sezam Telnet Service Configuration

Sezam supports three modes for handling PROXY protocol:

| Mode | Behavior |
|------|----------|
| `Auto` (default) | Detects if the connection begins with a PROXY header (v1 or v2). If found, extracts the remote client IP. If not found (or if direct connection / healthcheck), proceeds normally. |
| `Required` | Enforces that every incoming connection must begin with a valid PROXY protocol header. Malformed or non-proxy connections are immediately disconnected. |
| `Disabled` | Disables PROXY protocol parsing entirely; all connections are treated as direct connections. |

### Configuration via `appsettings.json`
```json
{
  "Telnet": {
    "Port": 2023,
    "ProxyProtocol": "Auto"
  }
}
```

### Configuration via Environment Variables (Docker / Swarm / Kubernetes)
Any of the following environment variables can be set:
- `PROXY_PROTOCOL=auto` (or `required`, `disabled`, `true`, `false`)
- `USE_PROXY_PROTOCOL=true`
- `Telnet__ProxyProtocol=Auto`

In `deployment.yaml`:
```yaml
services:
  tel:
    image: dev.zakic.net/sezam.net:latest
    environment:
      - REDIS_HOST=redis
      - DB_HOST=tux
      - PROXY_PROTOCOL=auto
```

---

## 3. Remote IP Propagation in Sezam

Once intercepted, the remote client IP is automatically reflected throughout Sezam:
- **`terminal.RemoteEndPoint`**: The real client `IPEndPoint` (e.g., `203.0.113.195:56324`).
- **`terminal.RemoteIPAddress`**: The real client `IPAddress` (e.g., `203.0.113.195`).
- **`terminal.ProxyEndPoint`**: The proxy socket endpoint that connected to the container.
- **`terminal.IsProxied`**: Set to `true` when forwarded via proxy.
- **`terminal.Id`**: Returns the real client endpoint string, used by `Session.ToString()`, `logger`, and `SessionInfo` for Redis distributed session tracking.
