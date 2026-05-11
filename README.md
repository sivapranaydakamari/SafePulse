# SafePulse

SafePulse is an AI-powered travel safety companion for real-time journey monitoring, route risk scoring, crash detection, and emergency response coordination.

## What It Does

- Authenticates users with OTP/JWT through the Node.js API.
- Maintains Safety Circles for trusted contacts and nearby responders.
- Tracks journey speed, phone-use risk, route risk, and emergency status.
- Scores safe-vs-short route options using OSRM/OpenStreetMap route data and incident-backed risk zones.
- Streams realtime tracking and SOS alerts through WebSockets.
- Analyzes accelerometer/gyroscope windows through a Python AI accident-analysis service.
- Persists emergency events in a Spring Boot microservice with JPA/H2 or an external SQL database.
- Sends SOS notifications through SMS/push notification adapters.

## Architecture

SafePulse uses a reviewable multi-service architecture:

- `frontend/` - Flutter mobile application with provider/repository/service separation.
- `backend/` - Node.js API gateway for auth, circles, route scoring, realtime WebSockets, alerts, and AI proxying.
- `backend-springboot/` - Spring Boot emergency-event microservice with JPA persistence.
- `ai-service/` - Python FastAPI accident-analysis microservice using TensorFlow Lite when available and a deterministic calibrated fallback.
- `.github/workflows/ci.yml` - GitHub Actions workflow for Node.js, Spring Boot, and Python service tests.

## Key Services

### Node.js API

Production deployment uses PM2 cluster mode (`ecosystem.config.js`) for load balancing across CPU cores.

- `POST /api/auth/send-otp`
- `POST /api/auth/verify-otp`
- `POST /api/routes/suggest`
- `GET /api/risk-zones`
- `POST /api/risk-zones`
- `POST /api/ai/accident/analyze`
- `POST /api/sos/start`
- `POST /api/sos` - gateway alias used by the autonomous background SOS path
- `WS /ws/tracking`
- `GET /health`

### Spring Boot Emergency Service

- `POST /api/sos`
- `GET /api/sos/{eventId}`
- `GET /api/sos/active`
- `PATCH /api/sos/{eventId}/resolve`

### Python AI Service

- `GET /health`
- `GET /v1/model/metadata`
- `POST /v1/accident/analyze`

## Local Development

### Node.js Backend

```powershell
cd backend
npm install
npm test
npm start
```

### Spring Boot Emergency Service

```powershell
cd backend-springboot
.\mvnw.cmd test
.\mvnw.cmd spring-boot:run
```

### Python AI Service

```powershell
cd ai-service
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 7000
```

Run the lightweight AI unit tests:

```powershell
cd ai-service
$env:PYTHONPATH='P:\SafePulse\ai-service'
python -m unittest discover -s tests
```

### Flutter Frontend

```powershell
cd frontend
flutter pub get
flutter test
flutter run --dart-define=BASE_URL=http://<backend-host>:5000
```

Note: `frontend/packages/telephony_fix` is a local patched Telephony plugin used for offline emergency SMS support. It keeps the app compatible with the Telephony API while allowing SafePulse to maintain the plugin fixes needed for SOS fallback behavior.

## Platform support

SafePulse officially targets Android only. The windows/ Flutter scaffold directory exists but is untested, unsupported, and excluded from all CI pipelines and releases.

## Docker deployment

All services can be started together with Docker Compose:

```bash
cp backend/.env.example backend/.env   # fill in secrets
docker compose up --build
```

| Service | Container port | Host port |
|---|---|---|
| Node.js API gateway | 5000 | 5000 |
| Spring Boot emergency service | 8080 | 8080 |
| Python AI service | 7000 | 7000 |
| MongoDB | 27017 | 27017 |

Each service has a minimal `Dockerfile` in its directory. The compose file wires the inter-service URLs automatically (`SPRING_EMERGENCY_SERVICE_URL`, `AI_SERVICE_URL`, `MONGODB_URI`).

## Future scope roadmap

### Phase 1 — Near-term

| Feature | Status | Scaffolding |
|---|---|---|
| Offline emergency queueing | Partial — SMS foundation via telephony_fix | sos_service.dart triggerOfflineSOS |
| Community safety reporting | Partial — risk incident infrastructure | risk_incident_repository.js |

### Phase 2 — Mid-term

| Feature | Status | Scaffolding |
|---|---|---|
| Advanced AI crash models | Partial — pluggable interpreter slot | ai_service.dart + ai-service/app/main.py |
| Live traffic + weather integration | Scaffolded | backend/services/traffic_weather_service.js |
| OBD-II vehicle integration | Scaffolded | lib/core/services/obd_service.dart |

### Phase 3 — Long-term

| Feature | Status | Scaffolding |
|---|---|---|
| Emergency service (police/ambulance) dispatch | Scaffolded | EmergencyDispatchService.java |
| Government emergency notification API | Planned | EmergencyDispatchService.java |
| Multi-region data residency | Planned | — |

## Verification Status

Current automated checks:

- Node.js backend: Jest route/service tests.
- Spring Boot emergency service: JUnit/MockMvc/JPA tests.
- Python AI service: crash analyzer unit tests.
- GitHub Actions: runs the Node.js, Spring Boot, and Python checks on push/pull request.

## Production Readiness Notes

- Keep secrets in environment variables, not source code.
- `JWT_SECRET` is required outside test runs; tests use an isolated test secret only.
- Node.js uses Helmet and rate limiting for API hardening.
- Use a managed MongoDB deployment with geospatial indexes enabled.
- Run the Spring Boot service with MySQL/PostgreSQL in production.
- Host the Python AI service separately and set `AI_SERVICE_URL` in the Node backend.
- Run the Spring Boot emergency service separately and set `SPRING_EMERGENCY_SERVICE_URL` in the Node backend.
- Replace public OSRM calls with a self-hosted or paid routing provider before production traffic.
- Use Firebase/Twilio production credentials only through secure environment configuration.
