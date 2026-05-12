# Changelog

All notable changes to SafePulse are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- Problem Statement traceability table in README linking each gap to its implementation
- nginx reverse proxy configuration (`backend/nginx.conf`) for TLS termination
- Roadmap section in README with versioned milestone table
- `CHANGELOG.md` (this file)

---

## [1.0.0] — 2025-05-12

### Added
- Flutter Android app: on-device TFLite crash detection (250-sample sliding window), autonomous SOS with offline SMS fallback, Safety Circle live map
- Node.js API Gateway: JWT auth, WebSocket real-time hub, global + auth rate limiting (Helmet + express-rate-limit), structured Morgan logging, X-Request-ID correlation
- Spring Boot Emergency Service: MongoDB-backed emergency event persistence with priority scoring and dispatch readiness flags
- Python FastAPI AI Service: TFLite crash analysis with calibrated heuristic fallback, phone-drop filtering, and `/ai/stats` inference metrics endpoint
- Safety Engine: over-speed monitoring (WARNING ≥ 65 km/h, CRITICAL ≥ 90 km/h), phone-use detection, stationary anomaly alerting with Safety Circle escalation
- Route Scoring: safety-ranked route suggestions from OSRM with MongoDB risk zone weighting (haversine proximity scoring)
- Firestore supplementary real-time location sync alongside WebSocket primary channel
- i18n scaffolding: ARB files for English (`app_en.arb`) and Hindi (`app_hi.arb`) with 5 initial keys
- CI: GitHub Actions matrix covering Flutter, Node.js, Spring Boot, and Python AI service
- Future-scope stub documentation: `LocalQueueService`, `CommunityReportService`, `OBDService`, `TrafficWeatherService`, `EmergencyDispatchService`
- TFLite warm-up inference on model load to eliminate first-inference latency spike
- `backend/TLS_SETUP.md` and `backend/nginx.conf` for production TLS termination via nginx

### Changed
- Migrated Spring Boot persistence from JPA/H2 to Spring Data MongoDB; tests use flapdoodle embedded MongoDB
- Replaced all `print()` calls with `debugPrint()` in Dart services (`ai_service.dart`, `route_service.dart`, `places_service.dart`)
- `/health` endpoints updated on both Node.js and Spring Boot services to report real-time DB connection status

### Fixed
- Added `import 'package:flutter/foundation.dart'` to `route_service.dart` and `places_service.dart` before replacing `print()` → `debugPrint()`
- `flutter_localizations` intl version conflict resolved (`^0.20.2` to match SDK constraint)
- `scoreRoutes(routes, null)` no longer throws — null guard added for `riskZones` parameter
