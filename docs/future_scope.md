# SafePulse — Future Scope

This document records planned and partially-implemented features. Fully-implemented items are marked ✅.

---

## ✅ 1. Offline Queue with Exponential Backoff

**Status:** Fully implemented  
**Files:** `frontend/lib/core/services/local_queue_service.dart`, `frontend/test/local_queue_service_test.dart`

Failed SOS/location events are persisted to SharedPreferences and retried with exponential back-off (30 s → 2 min → 10 min, max 3 attempts). A `processOnConnectivity()` listener drains the queue automatically when internet is restored.

---

## ✅ 2. Weather Risk Multipliers

**Status:** Fully implemented  
**Files:** `backend/services/traffic_weather_service.js`, `backend/services/route_scoring.js`, `frontend/lib/features/home/screens/route_suggestion_page.dart`

Live weather is fetched from Open-Meteo (no API key). Severity multipliers are applied to route risk scores:

| Condition   | Multiplier |
|-------------|-----------|
| Storm       | 2.0×      |
| Fog         | 1.5×      |
| Rain/Shower | 1.2×      |
| Clear       | 1.0×      |

A `weatherRiskFactor` field is included in every `/api/routes/suggest` response. The Flutter route page shows a prominent banner when `weatherRiskFactor > 1.5`.

---

## ✅ 3. Community Safety Reporting

**Status:** Fully implemented  
**Files:** `backend/models/CommunityReport.js`, `backend/routes/community.js`, `frontend/lib/core/services/community_report_service.dart`, `frontend/lib/features/home/screens/community_report_page.dart`

Users can report accidents, hazards, and road blocks with GPS location and a description. Reports are:
- Stored in MongoDB with a 2dsphere index and a 3-day TTL.
- Merged into route scoring as density-based risk zones (200 m radius each).
- Displayed as colored warning pins on the route map.
- Submitted via the "Report a Hazard" FAB on the route suggestion screen.

---

## ✅ 4. Government Emergency Dispatch

**Status:** Fully implemented  
**Files:** `backend-springboot/…/service/EmergencyDispatchService.java`, `backend-springboot/…/service/GovApiAdapter.java`, `backend-springboot/…/controller/EmergencyDispatchController.java`, `backend/routes/sos.js`

When an SOS is triggered with `severity > 0.8` (normalised 0–1), the Node.js SOS handler calls Spring Boot `POST /api/emergency/dispatch`. The `EmergencyDispatchService` uses a `PriorityQueue` ordered by severity score (highest first) and delegates to `GovApiAdapter`, which retries up to 3 times with a 5 s delay between attempts.

---

## ✅ 5. AI Model Monitoring

**Status:** Fully implemented  
**Files:** `ai-service/app/main.py`, `frontend/lib/features/safepulse/services/ai_service.dart`, `frontend/lib/core/services/api_service.dart`

After each on-device crash inference, the Flutter app posts telemetry (confidence, inference time, G-force, sensor hash) to `POST /api/ai/metrics/prediction`. Predictions with `confidence < 0.6` are flagged as uncertain and increment the false-positive counter used by `DriftMonitor`. The `GET /metrics` endpoint exposes the FP rate and triggers `drift_alert` when it exceeds 20 % or average latency exceeds 200 ms.

---

## 6. Multi-Language Support (i18n Scaffold)

**Status:** Scaffolded — needs content

**Plan:**
1. Add `flutter_localizations` and `intl` to `pubspec.yaml`.
2. Create ARB files:
   - `lib/l10n/app_en.arb` — English (default)
   - `lib/l10n/app_hi.arb` — Hindi
3. Replace all hardcoded user-facing strings with `AppLocalizations.of(context)!.<key>`.
4. Add a language picker in the Settings screen (stores choice in SharedPreferences).
5. Wire `MaterialApp.localizationsDelegates` and `supportedLocales`.

**ARB keys to cover (minimum):**
- `sos_triggered`, `sos_cancelled`, `route_safest`, `route_balanced`, `route_risky`
- `weather_alert`, `hazard_reported`, `emergency_dispatch_sent`
- All error / status strings visible to the user.

---

## 7. End-to-End Encrypted Emergency Communications

**Status:** Design documented — not yet implemented

**Design:**
- **Transport layer:** All SOS payloads already transit over HTTPS (TLS 1.3).
- **Application layer (planned):**
  1. On first app launch each user generates an RSA-2048 key pair; the public key is uploaded to the Node.js backend and stored in the `User` document.
  2. When a SOS notification is dispatched, the backend fetches each recipient's public key and encrypts the payload body (victim name, GPS location) with AES-256-GCM using a per-message ephemeral key.  The ephemeral key itself is encrypted with the recipient's RSA public key and included in the notification envelope.
  3. The receiving Flutter app decrypts the ephemeral key with its RSA private key (stored in Android Keystore), then decrypts the payload.
  4. FCM carries only the ciphertext envelope — no PII travels in plaintext through Google's infrastructure.

**Prerequisite:** Migrate FCM payload delivery to the `data`-only message type (currently uses `notification` + `data` hybrid which prevents payload encryption at the application layer).
