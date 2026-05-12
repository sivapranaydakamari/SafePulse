# SafePulse — Future Feature Issues

GitHub-issue-style stubs for the 7 partially-scaffolded future features.  
Each entry links to its existing scaffold and describes what remains before it can ship.

---

## Issue #1 — Full Offline SOS Queueing

**Title:** Implement persistent offline SOS queue with network-aware retry sync

**Current scaffold:**
- `frontend/lib/core/services/local_queue_service.dart` — `enqueue()`, `processQueue()`, `queueLocationUpdate()`
- `frontend/lib/features/safepulse/services/sos_service.dart` — `triggerOfflineSOS()` enqueues failed SMS

**What remains:**
- Queue entries are retried only on foreground resume; add a `BackgroundFetch` periodic sync every 15 minutes when offline.
- Expose a "Pending SOS" badge count in the UI using `LocalQueueService.getPendingCount()`.
- Add an exponential back-off so frequent retry failures don't drain battery.
- Write integration tests that mock network failure and verify the queue drains correctly on reconnect.

**Estimated effort:** 3–5 days

---

## Issue #2 — Live Traffic and Weather Risk in Route Scoring

**Title:** Incorporate real-time traffic congestion into safety route scoring

**Current scaffold:**
- `backend/services/traffic_weather_service.js` — `getWeatherRisk()` implemented (Open-Meteo); `getTrafficRisk()` returns Open-Meteo wind/precipitation proxy.
- `backend/services/route_scoring.js` — `scoreRoutesWithWeather()` applies weather multiplier.

**What remains:**
- Integrate HERE Traffic Flow API v3 or TomTom Traffic API for true congestion data.
- Feed congestion index (0–1) into `scoreRoutesWithWeather()` as a second multiplier.
- Cache traffic data with a 5-minute TTL (Redis or in-memory) to avoid per-request API calls.
- Display a traffic-severity icon next to each route card in the Flutter UI.

**Estimated effort:** 4–6 days

---

## Issue #3 — Voice Assistant / TTS Integration

**Title:** Hands-free SOS trigger and status updates via voice commands

**Current scaffold:**
- `flutter_tts` already in `pubspec.yaml`; `AlertService.speakWarning()` implemented.
- Architecture hook in `safepulse_engine.dart` for TTS alerts.

**What remains:**
- Integrate `speech_to_text` for wake-word detection ("Hey SafePulse, SOS").
- Add a hands-free mode toggle in Settings that activates the listener in the background.
- Localise voice prompts (Hindi supported via `app_hi.arb`; additional locales need ARB entries).
- Test on physical device with engine noise to calibrate recognition threshold.

**Estimated effort:** 5–7 days

---

## Issue #4 — Full i18n / Localisation

**Title:** Expand ARB locale support beyond English and Hindi

**Current scaffold:**
- `frontend/lib/l10n/app_en.arb` and `app_hi.arb` with 10 keys each.
- `AppLocalizations.localizationsDelegates` wired in `main.dart`.

**What remains:**
- Add ARB files for Tamil (`app_ta.arb`), Telugu (`app_te.arb`), and Kannada (`app_kn.arb`) — the three highest road-accident states in India.
- Replace hardcoded strings in `circle_map_page.dart`, `route_suggestion_page.dart`, and `driving_mode_page.dart` with `AppLocalizations.of(context)!.key` calls.
- Validate RTL layout for potential Arabic/Urdu expansion.
- Run `flutter gen-l10n` in CI to fail the build if ARB keys are missing.

**Estimated effort:** 3–5 days

---

## Issue #5 — OBD-II Vehicle Speed Integration

**Title:** Replace GPS-estimated speed with direct CAN bus data via ELM327 BLE

**Current scaffold:**
- `frontend/lib/core/services/obd_service.dart` — `OBDService` interface + `OBDServiceStub`
- `FeatureFlags.obdEnabled` gate (`--dart-define=OBD_ENABLED=true`)
- `frontend/lib/core/services/OBD_INTEGRATION.md` — full integration design doc

**What remains:**
- Implement `OBDServiceImpl` using `flutter_reactive_ble` to scan for ELM327 device.
- Parse OBD PID `0x010D` (Vehicle Speed) from the BLE characteristic response.
- Wire `OBDServiceImpl.speedStream` into `SafePulseEngine` (injection point is already commented in `safepulse_engine.dart`).
- Handle BLE disconnect gracefully — fall back to GPS speed.
- Write widget tests using a mock `BluetoothDevice` stream.

**Estimated effort:** 8–12 days

---

## Issue #6 — Community Hazard Reporting

**Title:** Allow users to submit crowd-sourced hazard pins visible on the route map

**Current scaffold:**
- `frontend/lib/core/services/community_report_service.dart` — `CommunityReportServiceImpl` with real HTTP calls.
- `FeatureFlags.communityReportsEnabled` gate.
- `backend/routes/risk_zones.js` — `createRiskIncident()` endpoint exists.

**What remains:**
- Enable `CommunityReportServiceImpl` as the active implementation when `FeatureFlags.communityReportsEnabled` is true.
- Build a "Report hazard" bottom sheet in the route suggestion page (photo + hazard type picker).
- Display community reports as map pins in `RouteSuggestionPage` and `CircleMapPage`.
- Add moderation: reports with fewer than 3 confirmations are shown as "unverified".
- Expire reports older than 24 hours via a MongoDB TTL index on `riskIncidents`.

**Estimated effort:** 5–8 days

---

## Issue #7 — Government Emergency Dispatch

**Title:** Auto-notify police or ambulance for CRITICAL-severity SOS events

**Current scaffold:**
- `backend-springboot/.../EmergencyDispatchService.java` — `dispatchEmergency()` stub; `dispatchRecommended` flag set by `EmergencyResponseService`.
- `SosController.java` — TODO comment for dispatch injection.

**What remains:**
- Implement `EmergencyDispatchService.dispatchEmergency()` to call the national emergency API (India: Dial 112 integrated API or Twilio emergency calling).
- Gate behind `dispatchRecommended == true && severity == CRITICAL`.
- Add a user consent flow: dispatch only if the user has pre-consented in Settings.
- Add idempotency: prevent duplicate dispatches for the same `eventId`.
- Write integration tests against a mock emergency API endpoint.

**Estimated effort:** 10–15 days (includes government API onboarding)
