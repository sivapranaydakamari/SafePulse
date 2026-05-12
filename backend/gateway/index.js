const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const GATEWAY_PORT = process.env.GATEWAY_PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3001';
const SPRINGBOOT_URL = process.env.SPRINGBOOT_URL || 'http://localhost:8080';
const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:8000';

// Python AI accident analysis — rewritten to FastAPI path
app.use('/api/ai/analyze', createProxyMiddleware({
  target: AI_SERVICE_URL,
  changeOrigin: true,
  pathRewrite: { '^/api/ai/analyze': '/v1/accident/analyze' },
}));

// Spring Boot emergency dispatch microservice
app.use('/api/emergency', createProxyMiddleware({
  target: SPRINGBOOT_URL,
  changeOrigin: true,
}));

// All remaining traffic (including WebSocket upgrade) → Node backend
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
