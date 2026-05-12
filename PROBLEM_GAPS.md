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

## Future Scope Stubs

Each gap has scaffolding for planned enhancements — see [README.md](README.md#future-scope) for details.
