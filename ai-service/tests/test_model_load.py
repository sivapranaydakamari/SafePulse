import importlib
import unittest

_FASTAPI_AVAILABLE = importlib.util.find_spec("fastapi") is not None


class TestModelLoad(unittest.TestCase):
    def test_tflite_available_flag_exists(self):
        """_TFLITE_AVAILABLE is set at import time and is a bool."""
        from app.services.crash_analyzer import _TFLITE_AVAILABLE
        self.assertIsInstance(_TFLITE_AVAILABLE, bool)

    def test_is_model_loaded_false_when_file_missing(self):
        """is_model_loaded is False when the model file does not exist."""
        from app.services.crash_analyzer import CrashAnalyzer
        analyzer = CrashAnalyzer(model_path="nonexistent_model.tflite")
        self.assertFalse(analyzer.is_model_loaded)
        self.assertEqual(analyzer.runtime_name, "heuristic")

    @unittest.skipUnless(_FASTAPI_AVAILABLE, "fastapi not installed — run after pip install -r requirements.txt")
    def test_health_endpoint_returns_200_with_model_keys(self):
        """GET /health returns 200 and includes status, model, and model_file keys."""
        from app.main import app
        from fastapi.testclient import TestClient
        client = TestClient(app)
        response = client.get("/health")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn(data["status"], ("ok", "degraded"))
        self.assertIn(data["model"], ("loaded", "failed"))
        self.assertIn("model_file", data)


if __name__ == "__main__":
    unittest.main()
