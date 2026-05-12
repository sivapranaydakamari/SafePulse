"""
Unit tests for AI service metrics endpoints.
FUTURE_SCOPE: AI MODEL MONITORING - fully implemented

Covers:
- GET /metrics — runtime stats + training metrics merge
- POST /metrics/prediction — telemetry ingestion + uncertain-confidence flagging
- POST /metrics/false-positive — explicit FP counter increment
"""

import importlib
import sys
import types
import unittest


def _make_app():
    """Import app.main with a stub CrashAnalyzer so no TFLite model is needed."""
    stub_analyzer = types.SimpleNamespace(
        is_model_loaded=False,
        model_path=type("P", (), {"name": "crash_model.tflite", "exists": lambda s: False})(),
        runtime_name="heuristic",
        analyze=lambda self, r: {"crashDetected": False, "crashProbability": 0.0, "modelUsed": "heuristic"},
        log_false_positive=lambda self, c, g: None,
        model_metadata=lambda self: {},
    )
    # Patch the module before importing main
    services_mod = types.ModuleType("app.services.crash_analyzer")
    services_mod.CrashAnalyzer = lambda: stub_analyzer
    services_mod.SensorReading = lambda **kw: kw
    sys.modules.setdefault("app.services", types.ModuleType("app.services"))
    sys.modules["app.services.crash_analyzer"] = services_mod

    import app.main as main_mod
    # Reset in-memory counters between test runs
    main_mod._inference_stats["total_inferences"] = 0
    main_mod._inference_stats["crash_detections"] = 0
    main_mod._inference_stats["total_ms"] = 0.0
    main_mod._false_positive_count = 0
    main_mod._prediction_log.clear()
    return main_mod.app


class TestMetricsGet(unittest.TestCase):
    def setUp(self):
        from fastapi.testclient import TestClient
        self.client = TestClient(_make_app())

    def test_metrics_returns_200(self):
        resp = self.client.get("/metrics")
        self.assertEqual(resp.status_code, 200)

    def test_metrics_contains_required_keys(self):
        resp = self.client.get("/metrics")
        data = resp.json()
        for key in ("total_inferences", "crash_detections", "false_positive_rate", "drift_alert"):
            self.assertIn(key, data, f"Missing key: {key}")

    def test_metrics_drift_alert_false_when_no_data(self):
        resp = self.client.get("/metrics")
        self.assertFalse(resp.json()["drift_alert"])


class TestPredictionPost(unittest.TestCase):
    def setUp(self):
        from fastapi.testclient import TestClient
        self.client = TestClient(_make_app())

    def test_log_prediction_returns_logged_true(self):
        resp = self.client.post("/metrics/prediction", json={
            "crash_detected": True,
            "confidence": 0.85,
            "inference_ms": 42.0,
            "g_force": 5.1,
            "sensor_hash": "abc123",
        })
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.json()["logged"])

    def test_uncertain_prediction_flagged(self):
        resp = self.client.post("/metrics/prediction", json={
            "crash_detected": True,
            "confidence": 0.45,
            "inference_ms": 55.0,
        })
        data = resp.json()
        self.assertTrue(data["uncertain"])
        self.assertGreater(data["false_positives"], 0)

    def test_confident_prediction_not_flagged(self):
        resp = self.client.post("/metrics/prediction", json={
            "crash_detected": True,
            "confidence": 0.92,
            "inference_ms": 30.0,
        })
        self.assertFalse(resp.json()["uncertain"])

    def test_no_crash_not_counted_as_fp(self):
        before = self.client.get("/metrics").json()["false_positives_logged"]
        self.client.post("/metrics/prediction", json={
            "crash_detected": False,
            "confidence": 0.1,
            "inference_ms": 20.0,
        })
        after = self.client.get("/metrics").json()["false_positives_logged"]
        self.assertEqual(before, after)


class TestFalsePositivePost(unittest.TestCase):
    def setUp(self):
        from fastapi.testclient import TestClient
        self.client = TestClient(_make_app())

    def test_explicit_fp_increments_counter(self):
        before = self.client.get("/metrics").json()["false_positives_logged"]
        self.client.post("/metrics/false-positive")
        after = self.client.get("/metrics").json()["false_positives_logged"]
        self.assertEqual(after, before + 1)


if __name__ == "__main__":
    unittest.main()
