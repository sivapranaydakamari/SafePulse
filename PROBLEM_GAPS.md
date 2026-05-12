# SafePulse — Problem Gap Coverage

This document maps each of the five identified road-safety gaps to the exact files and services that address them.

| # | Gap | Status | Core Files |
|---|-----|--------|-----------|
| 1 | **Over-speed monitoring** | Implemented | `sensor_service.dart`, `alert_service.dart`, `backend/services/safety_engine.js` |
| 2 | **Real-time crash detection** | Implemented | `ai_service.dart` (on-device TFLite, 250-sample window), `ai-service/app/services/crash_analyzer.py` (server-side FastAPI) |
| 3 | **Hands-free emergency alerting** | Implemented | `sos_service.dart` (autonomous SMS + call), `alert_service.dart` (TTS + torch + vibration), `local_queue_service.dart` (offline retry) |
| 4 | **Safety-scored route recommendations** | Implemented | `backend/services/route_scoring.js`, `backend/services/traffic_weather_service.js` (Open-Meteo weather multiplier), `frontend/lib/core/services/route_service.dart` |
| 5 | **Safety Circle real-time visibility** | Implemented | `realtime_tracking_service.dart` (WebSocket + Firestore mirror), `circle_map_page.dart`, `backend/services/realtime_hub.js` |

## Architecture Entry Point

All mobile traffic enters through the **Proxy Gateway** on port 3000.  
See [ARCHITECTURE.md](ARCHITECTURE.md) for the full service diagram.

---

## Verification

### GAP-01 — Over-speed Monitoring

**Primary implementation:**
- `backend/services/safety_engine.js` lines 41–97: `evaluateSafety(userId, speedKmh, isPhoneOn)` — computes WARNING/CRITICAL speed thresholds, triggers guardian broadcasts.
- `frontend/lib/features/safepulse/services/alert_service.dart` lines 55–80: `speakWarning()` — TTS announcement at WARNING speed.

**Test that validates it:**
- `backend/tests/service.test.js` → describe block `"evaluateSafety"` → `"warns at WARNING speed"` and `"triggers CRITICAL at high speed"`.

---

### GAP-02 — Real-time Crash Detection

**Primary implementation:**
- `frontend/lib/features/safepulse/services/ai_service.dart` lines 61–93: `addData()` — 50 Hz sensor ingestion into 250-sample sliding window.
- `frontend/lib/features/safepulse/services/ai_service.dart` lines 95–160: `_runAIAnalysis()` — TFLite inference or heuristic fallback; fires `onCrashDetected` callback.
- `frontend/lib/features/safepulse/services/ai_service.dart` lines 162–175: `runInference()` — `@visibleForTesting` surface for mock tests.
- `ai-service/app/services/crash_analyzer.py` lines 39–140: `CrashAnalyzer.analyze()` — server-side TFLite / heuristic validation.

**Tests that validate it:**
- `frontend/test/ai_service_mock_test.dart` → `"simulateCrashTrigger fires onCrashDetected callback"`, `"runInference returns null when model is not loaded"`.
- `ai-service/tests/test_crash_analyzer.py` → `"test_heuristic_mode_when_model_missing"`.

---

### GAP-03 — Hands-free Emergency Alerting

**Primary implementation:**
- `frontend/lib/features/safepulse/services/sos_service.dart` lines 57–85: `triggerHybridSOS()` — orchestrates online + offline SOS paths.
- `frontend/lib/features/safepulse/services/sos_service.dart` lines 154–200: `_executeEmergencySOSLocal()` — autonomous SMS + device call without user interaction.
- `frontend/lib/core/services/local_queue_service.dart` lines 14–88: `enqueue()` / `processQueue()` — offline retry queue with SharedPreferences persistence.

**Tests that validate it:**
- `frontend/test/sos_trigger_test.dart` → `"loadContacts parses pipe-format"`, `"empty contacts early exit"`.

---

### GAP-04 — Safety-scored Route Recommendations

**Primary implementation:**
- `backend/services/route_scoring.js` lines 65–115: `scoreRoutesWithWeather()` — applies risk-zone penalty + Open-Meteo weather multiplier, returns routes sorted by safety score.
- `backend/services/traffic_weather_service.js` lines 6–60: `TrafficWeatherService.getWeatherRisk()` — fetches precipitation/wind via Open-Meteo, returns 0–1 multiplier.

**Tests that validate it:**
- `backend/tests/route_scoring.test.js` → `"scoreRoutes returns sorted array"`, `"weather multiplier applied"`.
- `backend/tests/route_routes.test.js` → `"POST /api/routes/suggest"`.

---

### GAP-05 — Safety Circle Real-time Visibility

**Primary implementation:**
- `frontend/lib/core/services/realtime_tracking_service.dart` lines 72–130: `sendTrackingUpdate()` / `_mirrorLocationToFirestore()` — dual-path publish: WebSocket to Node.js hub and Firestore `live_locations` mirror.
- `frontend/lib/features/circles/screens/circle_map_page.dart`: `CircleMapPage` — listens to Firestore `live_locations` snapshots to render live guardian map.

**Tests that validate it:**
- `backend/tests/realtime_hub.test.js` → `"broadcasts tracking:update"`.
- `backend/tests/circle.test.js` → `"GET /api/circles/:id"`.

---

## Future Scope Stubs

Each gap has scaffolding for planned enhancements — see [README.md](README.md#future-scope) for details.
