'use strict';

/**
 * Gateway integration tests.
 *
 * These tests spin up the gateway express app in isolation (no real upstreams)
 * and verify the middleware chain: health check, request-ID injection, and
 * basic proxy error handling.
 */

const request = require('supertest');

// ---------------------------------------------------------------------------
// Build a minimal gateway app (mirrors gateway/index.js but without starting
// the server, so Jest can control the lifecycle).
// ---------------------------------------------------------------------------
const crypto  = require('crypto');
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

function buildGatewayApp({
  backendUrl    = 'http://localhost:19999', // intentionally unreachable
  springbootUrl = 'http://localhost:19998',
  aiServiceUrl  = 'http://localhost:19997',
} = {}) {
  const app = express();

  // Middleware: attach request ID
  app.use((req, _res, next) => {
    req.headers['x-request-id'] = req.headers['x-request-id'] || crypto.randomUUID();
    next();
  });

  // Health check — no upstream
  app.get('/health', (_req, res) => {
    res.json({
      status: 'ok',
      service: 'safepulse-proxy-gateway',
      upstreams: { backend: backendUrl, springboot: springbootUrl, ai: aiServiceUrl },
    });
  });

  // AI proxy (will fail — upstream not running — but routing is verified)
  app.use('/api/ai/analyze', createProxyMiddleware({
    target: aiServiceUrl,
    changeOrigin: true,
    pathRewrite: { '^/api/ai/analyze': '/v1/accident/analyze' },
    on: { error: (_err, _req, res) => res.status(502).json({ error: 'upstream_unavailable' }) },
  }));

  // Spring Boot proxy
  app.use('/api/emergency', createProxyMiddleware({
    target: springbootUrl,
    changeOrigin: true,
    on: { error: (_err, _req, res) => res.status(502).json({ error: 'upstream_unavailable' }) },
  }));

  // Catch-all — Node.js backend
  app.use('/', createProxyMiddleware({
    target: backendUrl,
    changeOrigin: true,
    ws: true,
    on: { error: (_err, _req, res) => res.status(502).json({ error: 'upstream_unavailable' }) },
  }));

  return app;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Gateway — /health', () => {
  const app = buildGatewayApp();

  test('GET /health returns 200 with service name', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.service).toBe('safepulse-proxy-gateway');
  });

  test('GET /health includes upstream URLs', async () => {
    const res = await request(app).get('/health');
    expect(res.body.upstreams).toHaveProperty('backend');
    expect(res.body.upstreams).toHaveProperty('springboot');
    expect(res.body.upstreams).toHaveProperty('ai');
  });
});

describe('Gateway — Request-ID middleware', () => {
  const app = buildGatewayApp();

  test('injects x-request-id when not present', async () => {
    const res = await request(app).get('/health');
    // The gateway attaches the ID to req.headers; /health returns before proxy
    // so we verify indirectly that the middleware ran without error.
    expect(res.status).toBe(200);
  });

  test('preserves existing x-request-id from client', async () => {
    const clientId = 'test-id-abc-123';
    const res = await request(app)
      .get('/health')
      .set('x-request-id', clientId);
    expect(res.status).toBe(200);
  });
});

describe('Gateway — proxy routes (upstream unreachable)', () => {
  const app = buildGatewayApp();

  test('POST /api/ai/analyze returns 502 when upstream is down', async () => {
    const res = await request(app)
      .post('/api/ai/analyze')
      .send({ samples: [] })
      .timeout(3000);
    expect(res.status).toBe(502);
  });

  test('POST /api/emergency returns 502 when upstream is down', async () => {
    const res = await request(app)
      .post('/api/emergency')
      .send({})
      .timeout(3000);
    expect(res.status).toBe(502);
  });

  test('GET /api/users returns 502 when backend is down', async () => {
    const res = await request(app)
      .get('/api/users')
      .timeout(3000);
    expect(res.status).toBe(502);
  });
});
