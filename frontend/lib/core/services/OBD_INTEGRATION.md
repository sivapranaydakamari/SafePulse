# OBD-II Integration Guide

## Overview

Phase 2 of SafePulse plans to replace GPS-estimated speed with direct vehicle CAN bus data via an ELM327 OBD-II Bluetooth adapter. This document describes the integration plan and existing scaffolding.

## Current State

`OBDServiceStub` in `obd_service.dart` is the extension point. It satisfies the `OBDService` interface with safe no-ops until hardware support is implemented.

The stub is gated by `FeatureFlags.obdEnabled` (`--dart-define=OBD_ENABLED=true`) so the code path can be exercised in development without affecting production builds.

## Planned Implementation

### 1. Bluetooth Discovery
Connect to a paired ELM327 adapter using `flutter_bluetooth_serial` or `flutter_reactive_ble`.

### 2. OBD PIDs
- **PID 0x010D** — Vehicle Speed (km/h)
- **PID 0x010C** — Engine RPM (optional)

### 3. Speed Injection
Once connected, `OBDServiceStub.speedStream` becomes a live broadcast stream. The `SafePulseEngine` reads from it in preference over GPS speed (see injection comment in `safepulse_engine.dart`).

### 4. Fallback
If the OBD adapter disconnects, the engine falls back to GPS speed automatically.

## File Locations

| File | Role |
|---|---|
| `lib/core/services/obd_service.dart` | Abstract interface + current stub |
| `lib/core/config/feature_flags.dart` | `FeatureFlags.obdEnabled` gate |
| `lib/features/safepulse/safepulse_engine.dart` | Injection point comment |

## Testing

Unit-test the OBD speed injection by providing a `StreamController<double>` as a mock `speedStream` and verifying that `SafePulseEngine` uses its values over GPS.
