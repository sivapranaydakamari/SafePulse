# SafePulse — Requirements Coverage Matrix

Status key: **Implemented** = code ships in production build | **Tested** = automated test exists | **Stubbed** = feature-flag-gated stub, not shipped by default

---

## Functional Requirements

| # | Requirement | Status | Key File(s) | Test |
|---|-------------|--------|-------------|------|
| FR-01 | Detect vehicle over-speed and alert user via TTS | Implemented, Tested | `frontend/lib/features/safepulse/services/alert_service.dart:55` — `speakWarning()` | `backend/tests/service.test.js` → `"warns at WARNING speed"` |
| FR-02 | Alert Safety Circle guardian when CRITICAL speed exceeded | Implemented, Tested | `backend/services/safety_engine.js:41` — `evaluateSafety()` | `backend/tests/service.test.js` → `"triggers CRITICAL at high speed"` |
| FR-03 | On-device crash detection from accelerometer/gyroscope (50 Hz, 250-sample window) | Implemented, Tested | `frontend/lib/features/safepulse/services/ai_service.dart:61` — `addData()` | `frontend/test/ai_service_mock_test.dart` → `"simulateCrashTrigger fires onCrashDetected"` |
| FR-04 | Server-side crash validation via Python AI service | Implemented, Tested | `ai-service/app/services/crash_analyzer.py:67` — `CrashAnalyzer.analyze()` | `ai-service/tests/test_crash_analyzer.py` → `"test_heuristic_mode_when_model_missing"` |
| FR-05 | Autonomous SOS — send SMS to emergency contacts without user interaction | Implemented, Tested | `frontend/lib/features/safepulse/services/sos_service.dart:57` — `triggerHybridSOS()` | `frontend/test/sos_trigger_test.dart` → `"loadContacts parses pipe-format"` |
| FR-06 | Offline SOS queue — retry SMS when no network | Implemented, Tested | `frontend/lib/core/services/local_queue_service.dart:64` — `processQueue()` | `frontend/test/sos_trigger_test.dart` → `"empty contacts early exit"` |
| FR-07 | Safety-scored route recommendations (OSRM + risk zones + weather) | Implemented, Tested | `backend/services/route_scoring.js:65` — `scoreRoutesWithWeather()` | `backend/tests/route_scoring.test.js` → `"scoreRoutes returns sorted array"` |
| FR-08 | Real-time weather risk multiplier on routes | Implemented, Tested | `backend/services/traffic_weather_service.js:6` — `getWeatherRisk()` | `backend/tests/route_routes.test.js` → `"POST /api/routes/suggest"` |
| FR-09 | Safety Circle — real-time live location for guardians | Implemented, Tested | `frontend/lib/core/services/realtime_tracking_service.dart:72` — `sendTrackingUpdate()` | `backend/tests/realtime_hub.test.js` → `"broadcasts tracking:update"` |
| FR-10 | Firestore live-location mirror for Safety Circle map | Implemented, Tested | `frontend/lib/core/services/realtime_tracking_service.dart:120` — `_mirrorLocationToFirestore()` | `backend/tests/circle.test.js` → `"GET /api/circles/:id"` |
| FR-11 | Push notifications via FCM to Safety Circle members | Implemented, Tested | `backend/services/notification_service.js` — `sendPushNotification()` | `backend/tests/notification_service.test.js` |
| FR-12 | Emergency event creation, retrieval and resolution (Spring Boot) | Implemented, Tested | `backend-springboot/.../EmergencyResponseService.java` — `createEvent()`, `resolveEvent()` | `backend-springboot/.../EmergencyResponseServiceTest.java` |
| FR-13 | Emergency dispatch recommendation with priority scoring | Implemented, Tested | `backend-springboot/.../EmergencyDispatchService.java` — `dispatchEmergency()` | `backend-springboot/.../EmergencyDispatchServiceTest.java` |
| FR-14 | OBD-II vehicle speed integration | Stubbed (flag-gated) | `frontend/lib/core/services/obd_service.dart` — `OBDServiceStub` (`OBD_ENABLED=false`) | `frontend/test/feature_flags_test.dart` → `"OBD integration is disabled by default"` |
| FR-15 | Community crowd-sourced hazard reporting | Stubbed (flag-gated) | `frontend/lib/core/services/community_report_service.dart` — `CommunityReportServiceStub` (`COMMUNITY_REPORTS_ENABLED=false`) | `frontend/test/feature_flags_test.dart` → `"Community reports are disabled by default"` |
| FR-16 | Advanced AI model with continuous retraining | Stubbed (flag-gated) | `ai-service/training/retrain.py` — full pipeline available behind `POST /retrain` (admin-gated) | `frontend/test/feature_flags_test.dart` → `"Advanced AI model is disabled by default"` |
| FR-17 | Offline i18n / TTS language support | Stubbed | `frontend/lib/l10n/` — ARB files present; runtime locale switching deferred | Documented in `docs/FUTURE_ISSUES.md` Issue #4 |
| FR-18 | Government/emergency dispatch integration | Stubbed | Dispatch flag in `EmergencyEvent.dispatchRecommended`; government API call deferred | Documented in `docs/FUTURE_ISSUES.md` Issue #7 |

---

## Technical Requirements

| # | Requirement | Status | Key File(s) | Notes |
|---|-------------|--------|-------------|-------|
| TR-01 | Flutter Android app (min SDK 21) | Implemented | `frontend/android/app/build.gradle` | iOS/Web excluded; Windows explicitly unsupported (`frontend/windows/UNSUPPORTED.md`) |
| TR-02 | Node.js API gateway with rate limiting + JWT auth | Implemented, Tested | `backend/gateway/index.js`, `backend/middleware/auth.js` | `backend/tests/gateway.test.js` covers 429, 401, valid JWT |
| TR-03 | Spring Boot emergency microservice (port 8080) | Implemented, Tested | `backend-springboot/src/main/java/com/safepulse/backend/` | Full Maven test suite |
| TR-04 | Python FastAPI AI service (port 8000) with TFLite | Implemented, Tested | `ai-service/app/main.py` | Heuristic fallback when model absent |
| TR-05 | MongoDB Atlas for persistent storage | Implemented | `backend/models/`, `backend-springboot/.../EmergencyEvent.java` | Mongoose + Spring Data MongoDB |
| TR-06 | Firebase Auth JWT validation | Implemented | `backend/middleware/auth.js` — `admin.auth().verifyIdToken()` | |
| TR-07 | Firebase FCM push notifications | Implemented | `backend/services/notification_service.js` — AES-256-CBC encrypted payloads | |
| TR-08 | Firestore real-time location mirror | Implemented | `frontend/lib/core/services/realtime_tracking_service.dart:120` | Supplementary to WebSocket |
| TR-09 | TFLite on-device inference | Implemented | `frontend/lib/features/safepulse/services/ai_service.dart` — `tflite_flutter` | Heuristic fallback when model absent |
| TR-10 | AES-256-CBC encryption for FCM payload | Implemented | `backend/services/notification_service.js` — `encryptMessage()` | See `docs/ENCRYPTION_DESIGN.md` |
| TR-11 | OSRM route geometry (3 alternatives) | Implemented | `backend/routes/route_routes.js` — `OSRM_URL` | |
| TR-12 | Twilio SMS/voice fallback | Implemented | `backend/services/notification_service.js` — `sendSMS()` | |
| TR-13 | ESLint + no-unused-vars/no-console/prefer-const/eqeqeq | Implemented | `backend/.eslintrc.json` | Enforced in CI `node-backend` step |
| TR-14 | firebase_options.dart excluded from VCS, .example present | Implemented | `.gitignore`, `frontend/lib/firebase_options.dart.example` | `scripts/check_firebase_config.sh` validates pre-build |
| TR-15 | Feature flags gate all unfinished stubs | Implemented, Tested | `frontend/lib/core/config/feature_flags.dart` | `frontend/test/feature_flags_test.dart` — all stubs disabled by default |
| TR-16 | AI model drift detection | Implemented | `ai-service/app/drift_monitor.py` — 7-day rolling FP rate, configurable threshold | `DRIFT_FP_THRESHOLD` env var |
| TR-17 | Model versioning + metrics endpoint | Implemented | `ai-service/app/main.py` — `GET /model/version`, `GET /metrics` | Reads `training/output/metrics.json` |
| TR-18 | Versioned TFLite export from retrain pipeline | Implemented | `ai-service/training/retrain.py` — `crash_model_v{timestamp}.tflite` + `metrics.json` | |
