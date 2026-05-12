"""
SafePulse AI — Drift Monitor

Tracks a rolling false-positive rate from inference logs.
When the FP rate exceeds a configurable threshold, emits a WARNING log
and (if Firestore is configured) writes an alert to admin/drift_alerts.

Usage (standalone):
    python -m app.drift_monitor

Integrated usage (called from main.py after each FP log):
    from app.drift_monitor import DriftMonitor
    monitor = DriftMonitor()
    monitor.record_inference(crash_detected=True)
    monitor.record_false_positive()
    alert = monitor.check_drift()  # returns True if drift detected
"""

import logging
import os
from collections import deque
from datetime import datetime, timezone

_log = logging.getLogger(__name__)

# Configurable via environment variable — default 20 %
_DRIFT_FP_THRESHOLD = float(os.getenv("DRIFT_FP_THRESHOLD", "0.20"))
# Rolling window: number of crash-detected inferences to track
_WINDOW_SIZE = int(os.getenv("DRIFT_WINDOW_SIZE", "50"))


class DriftMonitor:
    """
    Tracks a sliding window of crash detection outcomes and flags model drift
    when the false-positive rate exceeds the configured threshold.

    Thread safety: not thread-safe; use from a single async event loop or
    wrap calls in a threading.Lock for multi-threaded deployments.
    """

    def __init__(
        self,
        fp_threshold: float = _DRIFT_FP_THRESHOLD,
        window_size: int = _WINDOW_SIZE,
    ) -> None:
        self.fp_threshold = fp_threshold
        self.window_size = window_size
        # Deque of booleans: True = false positive, False = true positive
        self._window: deque[bool] = deque(maxlen=window_size)
        self._total_inferences = 0
        self._total_crash_detections = 0
        self._total_false_positives = 0
        self._drift_alert_active = False

    def record_inference(self, crash_detected: bool) -> None:
        """Call after every inference; crash_detected=True means model fired."""
        self._total_inferences += 1
        if crash_detected:
            self._total_crash_detections += 1

    def record_false_positive(self) -> None:
        """Call when the user (or heuristic) confirms a crash alert was a false positive."""
        self._total_false_positives += 1
        self._window.append(True)

    def record_true_positive(self) -> None:
        """Call when a crash alert is confirmed as a real crash."""
        self._window.append(False)

    @property
    def rolling_fp_rate(self) -> float:
        """False-positive rate over the current sliding window (0.0 – 1.0)."""
        if not self._window:
            return 0.0
        return sum(self._window) / len(self._window)

    def check_drift(self) -> bool:
        """
        Returns True if drift is detected (FP rate > threshold).
        Emits a WARNING log and attempts a Firestore alert on transition.
        """
        rate = self.rolling_fp_rate
        drift_now = rate > self.fp_threshold

        if drift_now and not self._drift_alert_active:
            _log.warning(
                "[DriftMonitor] DRIFT ALERT — rolling FP rate %.1f%% exceeds threshold %.1f%%. "
                "Retraining is recommended.",
                rate * 100,
                self.fp_threshold * 100,
            )
            self._drift_alert_active = True
            self._post_firestore_alert(rate)
        elif not drift_now and self._drift_alert_active:
            _log.info(
                "[DriftMonitor] Drift resolved — FP rate dropped to %.1f%%.", rate * 100
            )
            self._drift_alert_active = False

        return drift_now

    def _post_firestore_alert(self, fp_rate: float) -> None:
        """Write a drift alert to Firestore admin/drift_alerts if SDK is configured."""
        try:
            import firebase_admin  # type: ignore
            from firebase_admin import firestore  # type: ignore

            if not firebase_admin._apps:
                return  # Firebase not initialised in this process

            db = firestore.client()
            db.collection("admin").document("drift_alerts").set(
                {
                    "fp_rate": round(fp_rate, 4),
                    "threshold": self.fp_threshold,
                    "window_size": self.window_size,
                    "total_inferences": self._total_inferences,
                    "total_false_positives": self._total_false_positives,
                    "timestamp": datetime.now(tz=timezone.utc).isoformat(),
                    "retraining_recommended": True,
                },
                merge=True,
            )
            _log.info("[DriftMonitor] Firestore drift alert written.")
        except ImportError:
            _log.debug("[DriftMonitor] firebase_admin not available — skipping Firestore alert.")
        except Exception as exc:  # noqa: BLE001
            _log.warning("[DriftMonitor] Failed to write Firestore alert: %s", exc)

    @property
    def status(self) -> dict:
        """Return a summary dict suitable for the /metrics endpoint."""
        return {
            "rolling_fp_rate": round(self.rolling_fp_rate, 4),
            "fp_threshold": self.fp_threshold,
            "window_size": self.window_size,
            "window_filled": len(self._window),
            "drift_alert_active": self._drift_alert_active,
            "total_inferences": self._total_inferences,
            "total_false_positives": self._total_false_positives,
        }


# Module-level singleton used by main.py
drift_monitor = DriftMonitor()
