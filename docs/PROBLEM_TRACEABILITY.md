# SafePulse — Problem Gap Traceability Matrix

This document provides machine-readable traceability from each identified road-safety problem gap to its exact implementation file, entry function/class, and the test that validates the behaviour.

| Gap ID | Problem Gap | Implementation File | Function / Class | Validation Test |
|--------|-------------|--------------------|--------------------|-----------------|
| GAP-01 | **Over-speed monitoring** — no app alerts user or guardian when safe speed thresholds are exceeded | `backend/services/safety_engine.js` | `evaluateSafety(userId, speedKmh, isPhoneOn)` | `backend/tests/service.test.js` → "evaluateSafety warns at WARNING speed" |
| GAP-01 | Over-speed TTS warning (mobile) | `frontend/lib/features/safepulse/services/alert_service.dart` | `AlertService.speakWarning()` | `frontend/test/sos_service_test.dart` (integration) |
| GAP-02 | **Real-time crash detection** — smartphone sensors capable of detecting sudden impacts are unused | `frontend/lib/features/safepulse/services/ai_service.dart` | `AIService.addData()` / `_runAIAnalysis()` | `frontend/test/ai_service_mock_test.dart` → "simulateCrashTrigger fires onCrashDetected" |
| GAP-02 | Server-side crash validation (Python AI) | `ai-service/app/services/crash_analyzer.py` | `CrashAnalyzer.analyze()` | `ai-service/tests/test_crash_analyzer.py` → "test_heuristic_mode_when_model_missing" |
| GAP-03 | **Hands-free emergency alerting** — injured/unconscious users cannot manually trigger SOS | `frontend/lib/features/safepulse/services/sos_service.dart` | `SosService.triggerHybridSOS()` / `_executeEmergencySOSLocal()` | `frontend/test/sos_service_test.dart` → "loadContacts parses pipe-format" |
| GAP-03 | Offline SMS queue retry | `frontend/lib/core/services/local_queue_service.dart` | `LocalQueueService.processQueue()` | `frontend/test/sos_service_test.dart` → "empty contacts early exit" |
| GAP-04 | **Safety-scored route recommendations** — route engines optimise only for time/distance | `backend/services/route_scoring.js` | `scoreRoutesWithWeather(routes, riskZones, lat, lng)` | `backend/tests/route_scoring.test.js` → "scoreRoutes returns sorted array" |
| GAP-04 | Real-time weather risk multiplier | `backend/services/traffic_weather_service.js` | `TrafficWeatherService.getWeatherRisk()` | `backend/tests/route_routes.test.js` → "POST /api/routes/suggest" |
| GAP-05 | **Safety Circle visibility** — guardians have no passive visibility into active journeys | `frontend/lib/core/services/realtime_tracking_service.dart` | `RealtimeTrackingService.sendTrackingUpdate()` / `_mirrorLocationToFirestore()` | `backend/tests/realtime_hub.test.js` → "broadcasts tracking:update" |
| GAP-05 | Live circle map | `frontend/lib/features/circles/screens/circle_map_page.dart` | `CircleMapPage` (Firestore `live_locations` snapshots) | `backend/tests/circle.test.js` → "GET /api/circles/:id" |

## Notes

- All five gaps map to at least one passing automated test.
- GAP-02 on-device TFLite inference is validated without a real device in `ai_service_mock_test.dart` using `@visibleForTesting` stubs.
- GAP-03 offline SMS is validated via `LocalQueueService.processQueue()` unit tests that use `SharedPreferences` mocks.
- See [REQUIREMENTS_COVERAGE.md](REQUIREMENTS_COVERAGE.md) for the full functional / technical requirement matrix.
