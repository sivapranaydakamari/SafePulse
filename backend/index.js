/**
 * SafePulse Node.js Backend — internal microservice on port 3001.
 *
 * Public traffic must enter through the Proxy Gateway (gateway/index.js, port 3000).
 * The gateway proxies all non-AI, non-emergency requests here after:
 *   (1) attaching a UUID X-Request-ID header for distributed tracing,
 *   (2) passing through the global rate limiter (300 req / 15 min per IP),
 *   (3) validating the Firebase Auth JWT via the gateway's auth middleware,
 *   (4) forwarding the request with the original Authorization header preserved, and
 *   (5) surfacing a 502 to the client if this service is unreachable.
 *
 * Request lifecycle inside this service:
 *   1. requestId middleware  — preserves or stamps X-Request-ID from gateway.
 *   2. helmet                — sets secure HTTP response headers (CSP, HSTS, etc.).
 *   3. globalLimiter         — secondary rate limit (safety net if gateway is bypassed in dev).
 *   4. Route handlers        — /api/auth · /api/circle · /api/journey · /api/routes · /api/sos · …
 *   5. Mongoose / realtimeHub — persistence to MongoDB Atlas + WebSocket fan-out to Safety Circle.
 *
 * Do NOT expose port 3001 directly in production.
 */
const express   = require('express');
const mongoose  = require('mongoose');
const cors      = require('cors');
const dotenv    = require('dotenv');
const http      = require('http');
const https     = require('https');
const fs        = require('fs');
const helmet    = require('helmet');
const morgan    = require('morgan');
const rateLimit = require('express-rate-limit');
const requestId = require('./middleware/requestId');
const { createRealtimeHub } = require('./services/realtime_hub');
const { isFcmReady } = require('./services/notification_service');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;
const server = http.createServer(app);
const realtimeHub = createRealtimeHub(server);
app.set('realtimeHub', realtimeHub);

const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: process.env.NODE_ENV === 'test' ? 1000 : 300,
  standardHeaders: true,
  legacyHeaders: false,
});

const authLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: process.env.NODE_ENV === 'test' ? 1000 : 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many authentication attempts. Please try again later.' },
});

app.use(requestId);
app.use(helmet());
app.use(globalLimiter);
app.use(cors());
app.use(express.json());
app.use(
  process.env.NODE_ENV === 'production'
    ? morgan('combined')
    : morgan('dev')
);

// Routes
app.use('/api/auth', authLimiter, require('./routes/auth'));
app.use('/api/circle', require('./routes/circle'));
app.use('/api/journey', require('./routes/journey'));
app.use('/api/routes', require('./routes/route_routes'));
app.use('/api/sos', require('./routes/sos'));
app.use('/api/places', require('./routes/places'));
app.use('/api/services', require('./routes/services'));
app.use('/api/alerts', require('./routes/alerts'));
app.use('/api/overpass', require('./routes/overpass'));
app.use('/api/support', require('./routes/support'));
app.use('/api/crime', require('./routes/crime_routes'));
app.use('/api/risk-zones', require('./routes/risk_zones'));
app.use('/api/ai',       require('./routes/ai'));

app.get('/', (req, res) => res.send('SafePulse API v2 running'));
app.get('/health', (req, res) => {
  const mongoStatus = mongoose.connection.readyState === 1 ? 'ok' : 'disconnected';
  if (mongoStatus !== 'ok') {
    return res.status(503).json({ status: 'degraded', mongo: mongoStatus });
  }
  res.json({
    status: 'ok',
    mongo: mongoStatus,
    service: 'safepulse-api-gateway',
    realtime: realtimeHub.isEnabled,
    fcm: isFcmReady() ? 'ok' : 'not_configured',
  });
});

const _log = (level, event, extra = {}) =>
  console.log(JSON.stringify({ level, service: 'safepulse-gateway', event, ...extra }));

// MongoDB — server only starts after a successful connection
mongoose.connect(process.env.MONGODB_URI)
  .then(async () => {
    _log('info', 'mongodb_connected');
    try {
      const User = require('./models/User');
      await User.collection.dropIndex('phone_1');
      _log('info', 'index_refreshed', { index: 'phone_1' });
    } catch (e) { }
    try {
      const User = require('./models/User');
      await User.collection.dropIndex('email_1');
      _log('info', 'index_refreshed', { index: 'email_1' });
    } catch (e) { }

    // === TLS / HTTPS SERVER ===
    // In production, set USE_HTTPS=true and provide TLS cert paths via environment variables.
    // In development, the server runs on plain HTTP (USE_HTTPS defaults to false).
    // TLS termination can also be handled externally by nginx — see TLS_SETUP.md.
    if (process.env.USE_HTTPS === 'true') {
      const tlsOptions = {
        key:  fs.readFileSync(process.env.TLS_KEY_PATH  || './certs/server.key'),
        cert: fs.readFileSync(process.env.TLS_CERT_PATH || './certs/server.crt'),
      };
      https.createServer(tlsOptions, app).listen(process.env.HTTPS_PORT || 443, () => {
        _log('info', 'server_start', { port: process.env.HTTPS_PORT || 443, protocol: 'https', env: process.env.NODE_ENV });
      });
    } else {
      // Bind to 0.0.0.0 so physical devices on the LAN can connect
      server.listen(PORT, '0.0.0.0', () => {
        _log('info', 'server_start', { port: PORT, protocol: 'http', env: process.env.NODE_ENV });
        _log('info', 'websocket_ready', { url: `ws://0.0.0.0:${PORT}/ws/tracking` });
      }).on('error', (err) => {
        if (err.code === 'EADDRINUSE') {
          _log('error', 'port_in_use', { port: PORT, hint: `netstat -ano | findstr :${PORT}` });
          process.exit(1);
        } else {
          _log('error', 'server_error', { message: err.message });
          process.exit(1);
        }
      });
    }
  })
  .catch(err => {
    _log('error', 'mongodb_connection_failed', { message: err.message });
    process.exit(1);
  });
