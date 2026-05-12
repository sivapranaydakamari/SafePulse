# SafePulse — Microservice Registry

| Service | Technology | Port | Health Endpoint | CI Step | Start Command |
|---------|-----------|------|----------------|---------|--------------|
| **Proxy Gateway** | Node.js, http-proxy-middleware | **3000** (public) | `GET /health` | `node-backend` → syntax check | `node gateway/index.js` |
| **Node.js Backend** | Node.js 22, Express, Mongoose | 3001 (internal) | `GET /health` | `node-backend` → `npm test` | `node index.js` |
| **Spring Boot Emergency** | Java 17, Spring Boot 3, Spring Data MongoDB | 8080 (internal) | `GET /actuator/health` | `springboot-emergency-service` → `./mvnw test` | `./mvnw spring-boot:run` |
| **Python AI Service** | Python 3.11, FastAPI, tflite-runtime | 8000 (internal) | `GET /health` | `python-ai-service` → `python -m unittest discover` | `uvicorn app.main:app --port 8000` |
| **Flutter App** | Flutter 3.x, Dart, Android | N/A (mobile) | N/A | `flutter-frontend` → `flutter test` + APK build | `flutter run` |

## Database & External Services

| Service | Technology | Usage |
|---------|-----------|-------|
| **MongoDB Atlas** | MongoDB (geospatial 2dsphere indexes) | All microservices — users, circles, SOS, incidents, journeys |
| **Firebase Auth** | Firebase Authentication | User sign-in / OTP / JWT token management |
| **Firebase FCM** | Firebase Cloud Messaging | Push notifications for SOS alerts and Safety Circle events |
| **Firestore** | Cloud Firestore | Supplementary live-location mirror (`live_locations` collection) |
| **Twilio** | Twilio SMS / Voice | Offline SMS and emergency call fallback |
| **OSRM** | Open Source Routing Machine | Route geometry (3 alternatives per request) |
| **Open-Meteo** | Free weather API | Weather risk scoring (no API key required) |

## PM2 Process Names

```bash
pm2 start ecosystem.config.js --env production
pm2 list
# safepulse-proxy-gateway   fork   port 3000
# safepulse-gateway         cluster port 3001 (max instances)
```

Spring Boot and Python services are managed separately (systemd or Docker in production).
