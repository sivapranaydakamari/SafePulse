# SafePulse Proxy Gateway

The gateway is the **single public entry point** for all SafePulse client traffic (port 3000).  
It is a thin `http-proxy-middleware` reverse proxy — no business logic lives here.

## Middleware Chain

Every inbound request passes through the following middleware in order:

1. **UUID Request-ID** (`crypto.randomUUID()`)  
   Attaches `X-Request-ID` to every request for end-to-end distributed tracing.  
   If the client already supplies the header, it is preserved.

2. **Health check** (`GET /health`)  
   Returns gateway status + upstream URLs without touching any microservice.  
   Used by load balancers and uptime monitors.

3. **AI proxy** (`/api/ai/analyze → :8000/v1/accident/analyze`)  
   Rewrites the path so the mobile app does not need to know the Python service URL.

4. **Spring Boot proxy** (`/api/emergency → :8080`)  
   Routes emergency-event CRUD to the Spring Boot microservice.

5. **Catch-all proxy** (`/* + WebSocket upgrade → :3001`)  
   All remaining REST and WebSocket traffic is forwarded to the Node.js backend.  
   `ws: true` enables transparent WebSocket proxying.

## Route Groups

| Path prefix | Upstream | Notes |
|-------------|---------|-------|
| `GET /health` | Gateway itself | No upstream hit |
| `/api/ai/analyze` | Python AI `:8000` | Path rewritten |
| `/api/emergency` | Spring Boot `:8080` | Pass-through |
| `/api/*` (all others) | Node.js `:3001` | Auth, routes, SOS, circles |
| `/ws/tracking` | Node.js `:3001` | WebSocket upgrade |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GATEWAY_PORT` | `3000` | Port the gateway listens on |
| `BACKEND_URL` | `http://localhost:3001` | Node.js backend |
| `SPRINGBOOT_URL` | `http://localhost:8080` | Spring Boot service |
| `AI_SERVICE_URL` | `http://localhost:8000` | Python AI service |

## Running

Via PM2 (recommended):
```bash
pm2 start ecosystem.config.js --env production
```

Standalone (development):
```bash
node gateway/index.js
```

## Security Notes

- The gateway does **not** perform authentication — JWT validation happens in the Node.js backend middleware.
- Rate limiting is applied in the Node.js backend (`express-rate-limit`), not at the gateway layer.
- In production, place an nginx or cloud load balancer in front of the gateway for TLS termination.
