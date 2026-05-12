/**
 * SafePulse Proxy Gateway — single public entry point (port 3000).
 *
 * All mobile client traffic enters here.  The gateway routes requests to the
 * appropriate internal microservice and never exposes microservice ports
 * directly to the internet.
 *
 *   /api/ai/analyze   → Python AI Service  :8000  (/v1/accident/analyze)
 *   /api/emergency    → Spring Boot Service :8080
 *   everything else   → Node.js Backend    :3001  (REST + WebSocket upgrade)
 *
 * Start via PM2:  pm2 start ecosystem.config.js --env production
 */

const crypto  = require('crypto');
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const GATEWAY_PORT   = process.env.GATEWAY_PORT   || 3000;
const BACKEND_URL    = process.env.BACKEND_URL     || 'http://localhost:3001';
const SPRINGBOOT_URL = process.env.SPRINGBOOT_URL  || 'http://localhost:8080';
const AI_SERVICE_URL = process.env.AI_SERVICE_URL  || 'http://localhost:8000';

// Attach a unique request ID to every inbound request for end-to-end tracing.
app.use((req, _res, next) => {
  req.headers['x-request-id'] = req.headers['x-request-id'] || crypto.randomUUID();
  next();
});

// Gateway health check — does not touch upstream services.
app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'safepulse-proxy-gateway',
    upstreams: {
      backend:    BACKEND_URL,
      springboot: SPRINGBOOT_URL,
      ai:         AI_SERVICE_URL,
    },
  });
});

/**
 * Route group → upstream mapping
 * ─────────────────────────────────────────────────────────────────────────────
 * /api/ai/analyze    → Python FastAPI :8000  (/v1/accident/analyze)
 *                      Called by the Flutter app for server-side crash validation.
 *
 * /api/emergency/*   → Spring Boot :8080  (EmergencyResponseService)
 *                      Stores and retrieves emergency events created server-side.
 *                      The Flutter app does NOT call /api/emergency directly —
 *                      Node.js backend calls Spring Boot internally via
 *                      emergency_event_client.js after processing an SOS event.
 *
 * /api/sos/*         → Node.js Backend :3001  (routes/sos.js)
 *                      This is the primary SOS entry point for the mobile app.
 *                      After persisting the SOS, the Node.js service calls
 *                      Spring Boot POST /api/sos internally (server-to-server).
 *                      Spring Boot's POST /api/sos is therefore NEVER reached
 *                      directly from the mobile client.
 *
 * /* (everything else, including WebSocket /ws/tracking)
 *                    → Node.js Backend :3001
 * ─────────────────────────────────────────────────────────────────────────────
 */

// Python AI accident analysis → FastAPI /v1/accident/analyze
app.use('/api/ai/analyze', createProxyMiddleware({
  target: AI_SERVICE_URL,
  changeOrigin: true,
  pathRewrite: { '^/api/ai/analyze': '/v1/accident/analyze' },
}));

// Python AI metrics endpoints (prediction logging, false-positive reporting)
app.use('/api/ai/metrics', createProxyMiddleware({
  target: AI_SERVICE_URL,
  changeOrigin: true,
  pathRewrite: { '^/api/ai/metrics': '/metrics' },
}));

// Spring Boot emergency dispatch microservice.
// Reached server-to-server from Node.js only — NOT from the mobile app.
app.use('/api/emergency', createProxyMiddleware({
  target: SPRINGBOOT_URL,
  changeOrigin: true,
}));

// All remaining traffic (including WebSocket upgrade) → Node.js backend.
// Includes /api/sos/*, /api/auth/*, /api/circle/*, /api/routes/*, /ws/tracking.
app.use('/', createProxyMiddleware({
  target: BACKEND_URL,
  changeOrigin: true,
  ws: true,
}));

app.listen(GATEWAY_PORT, '0.0.0.0', () => {
  console.log(JSON.stringify({
    level: 'info',
    service: 'safepulse-proxy-gateway',
    event: 'start',
    port: GATEWAY_PORT,
    upstream: { backend: BACKEND_URL, springboot: SPRINGBOOT_URL, ai: AI_SERVICE_URL },
  }));
});
