/**
 * SafePulse Safety Engine — Problem Gap #1 (over-speed) and #5 (Safety Circle).
 *
 * Evaluates real-time sensor data from the WebSocket tracking stream and
 * returns a safety status verdict for each connected user.  The verdict drives
 * TTS warnings on the mobile app and optional Safety Circle notifications.
 *
 * Constants:
 *   WARNING_SPEED_KMH  — speed above which a verbal warning is issued
 *   CRITICAL_SPEED_KMH — speed above which the Safety Circle is notified
 *   STATIONARY_TIMEOUT — seconds of zero movement before a stationary alert
 *   PHONE_USE_SPEED_MIN — minimum speed (km/h) at which phone use is flagged
 *
 * Exported functions:
 *   evaluateSafety(userId, speedKmh, isPhoneOn) → { status, message, warningSent, circleNotified }
 *   clearState(userId) — removes in-memory state when a journey ends
 */

// Speed thresholds are the single source of truth in backend/config/speed_constants.js.
// The Dart equivalents in warning_service.dart (kSpeedWarningMs, kSpeedCriticalMs)
// must be kept in sync manually — see the comment in speed_constants.js.
const { WARNING_SPEED_KMH, CRITICAL_SPEED_KMH } = require('../config/speed_constants');
const STATIONARY_TIMEOUT  = 120;  // seconds stopped before alert
const PHONE_USE_SPEED_MIN = 10;   // km/h — using phone above this is dangerous

const userState = {};

function getState(userId) {
  if (!userState[userId]) {
    userState[userId] = {
      lastSpeedUpdate: Date.now(),
      stationaryStart: null,
      warningCount: 0,
    };
  }
  return userState[userId];
}

/**
 * Evaluate current safety status.
 * Returns: { status, message, warningSent, circleNotified }
 */
function evaluateSafety(userId, speedKmh, isPhoneOn) {
  const state = getState(userId);
  const now = Date.now();

  let status = 'SAFE';
  let message = null;
  let warningSent = false;
  let circleNotified = false;

  // 1. Phone use while moving
  if (isPhoneOn && speedKmh > PHONE_USE_SPEED_MIN) {
    status = 'WARNING';
    message = `Phone screen on at ${speedKmh.toFixed(0)} km/h. Stay focused.`;
    warningSent = true;
  }

  // 2. Speed check
  if (speedKmh > CRITICAL_SPEED_KMH) {
    status = 'CRITICAL';
    message = `Speed ${speedKmh.toFixed(0)} km/h is dangerously high. Slowing down.`;
    warningSent = true;
    circleNotified = true;
  } else if (speedKmh > WARNING_SPEED_KMH) {
    status = 'WARNING';
    message = `Speed ${speedKmh.toFixed(0)} km/h exceeds safe limit. Please slow down.`;
    warningSent = true;
  }

  // 3. Sudden stop detection
  if (speedKmh < 2) {
    if (!state.stationaryStart) {
      state.stationaryStart = now;
    } else {
      const stoppedSec = (now - state.stationaryStart) / 1000;
      if (stoppedSec > STATIONARY_TIMEOUT) {
        status = 'WARNING';
        message = `You have been stationary for ${Math.round(stoppedSec / 60)} minutes.`;
        warningSent = true;
        // After 5 min, notify circle
        if (stoppedSec > STATIONARY_TIMEOUT * 2.5) {
          circleNotified = true;
          message = `User has been stationary for over 5 minutes. May need assistance.`;
        }
      }
    }
  } else {
    state.stationaryStart = null;
  }

  state.lastSpeedUpdate = now;
  return { status, message, warningSent, circleNotified };
}

function clearState(userId) {
  delete userState[userId];
}

module.exports = { evaluateSafety, clearState };
