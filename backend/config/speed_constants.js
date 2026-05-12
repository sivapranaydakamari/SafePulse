'use strict';

/**
 * SafePulse speed thresholds — single source of truth for both backend and frontend.
 *
 * Backend consumers: backend/services/safety_engine.js
 * Frontend mirror:   frontend/lib/features/safepulse/services/warning_service.dart
 *   → kSpeedWarningMs  = WARNING_SPEED_KMH  / 3.6  ≈ 18.0 m/s
 *   → kSpeedCriticalMs = CRITICAL_SPEED_KMH / 3.6  ≈ 25.0 m/s
 *
 * If you change either value here, update the corresponding constants in
 * warning_service.dart and the inline comment documenting km/h equivalents.
 */

const WARNING_SPEED_KMH  = 65;  // over this → verbal TTS warning issued to driver
const CRITICAL_SPEED_KMH = 90;  // over this → Safety Circle guardian notified

module.exports = { WARNING_SPEED_KMH, CRITICAL_SPEED_KMH };
