const express   = require('express');
const mongoose  = require('mongoose');
const cors      = require('cors');
const dotenv    = require('dotenv');
const http      = require('http');
const https     = require('https');
const fs        = require('fs');
const helmet    = require('helmet');
const rateLimit = require('express-rate-limit');
const { createRealtimeHub } = require('./services/realtime_hub');

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

// === API GATEWAY LAYER ===
// This process acts as the sole public-facing entry point for all SafePulse
// services. Responsibilities:
//   • TLS termination  — handled by the nginx reverse proxy in front of this
//     process (see backend/TLS_SETUP.md for the recommended nginx config).
//   • Rate limiting    — express-rate-limit on all routes (globalLimiter) and
//     a tighter limit on auth endpoints (authLimiter).
//   • Authentication   — JWT validation via requireAuth middleware before any
//     protected route handler executes.
//   • Request logging  — structured timestamp + method + URL logged below.
//   • Routing          — all /api/* paths fanned out to service-specific routers.
app.use(helmet());
app.use(globalLimiter);
app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
  console.log(
    `[${new Date().toISOString()}] ${req.method} ${req.url}`
  );
  if (req.method !== 'GET') console.log('  Body:', req.body);
  next();
});

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
  const dbReady = mongoose.connection.readyState === 1;
  if (!dbReady) {
    return res.status(503).json({ status: 'degraded', db: 'disconnected' });
  }
  res.json({
    status: 'ok',
    db: 'connected',
    service: 'safepulse-api-gateway',
    realtime: realtimeHub.isEnabled,
  });
});

// MongoDB — server only starts after a successful connection
mongoose.connect(process.env.MONGODB_URI)
  .then(async () => {
    console.log('✅ MongoDB connected');
    try {
      const User = require('./models/User');
      await User.collection.dropIndex('phone_1');
      console.log('Refreshed phone index');
    } catch (e) { }
    try {
      const User = require('./models/User');
      await User.collection.dropIndex('email_1');
      console.log('Refreshed email index');
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
        console.log(`[Gateway] HTTPS server running on port ${process.env.HTTPS_PORT || 443}`);
      });
    } else {
      // Bind to 0.0.0.0 so physical devices on the LAN can connect
      server.listen(PORT, '0.0.0.0', () => {
        console.log(`SafePulse API listening on 0.0.0.0:${PORT}`);
        console.log(`SafePulse realtime WebSocket ready at ws://0.0.0.0:${PORT}/ws/tracking`);
      }).on('error', (err) => {
        if (err.code === 'EADDRINUSE') {
          console.error(`❌ Port ${PORT} is already in use. Kill the other process first:`);
          console.error(`   Windows: netstat -ano | findstr :${PORT}  then  taskkill /PID <pid> /F`);
          process.exit(1);
        } else {
          console.error('Server error:', err);
          process.exit(1);
        }
      });
    }
  })
  .catch(err => {
    console.error('❌ MongoDB connection failed. Server will not start:', err.message);
    process.exit(1);
  });
