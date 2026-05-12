import logging
import os
import subprocess
import sys

from fastapi import FastAPI, HTTPException, Header

from app.schemas import AccidentAnalysisRequest, AccidentAnalysisResponse
from app.services.crash_analyzer import CrashAnalyzer, SensorReading

logging.basicConfig(level=logging.INFO)
_log = logging.getLogger(__name__)

app = FastAPI(
    title="SafePulse AI Accident Analysis Service",
    version="1.0.0",
    description="Server-side TensorFlow Lite crash analysis and phone-drop filtering.",
)

analyzer = CrashAnalyzer()
if analyzer.is_model_loaded:
    _log.info("[AIService] TFLite model loaded: %s — inference ready", analyzer.model_path.name)
else:
    _log.warning("[AIService] TFLite model unavailable — running in heuristic mode")

_inference_count: int = 0
_last_inference_ms: float = 0.0
_inference_stats: dict = {
    "total_inferences": 0,
    "crash_detections": 0,
    "total_ms": 0.0,
}


@app.get("/health")
def health() -> dict:
    if analyzer.is_model_loaded:
        return {
            "status": "ok",
            "model": "loaded",
            "model_file": analyzer.model_path.name,
        }
    return {
        "status": "degraded",
        "model": "failed",
        "model_file": analyzer.model_path.name,
    }


@app.get("/v1/model/metadata")
def model_metadata() -> dict:
    return analyzer.model_metadata()


@app.post("/v1/accident/analyze", response_model=AccidentAnalysisResponse)
def analyze_accident(payload: AccidentAnalysisRequest) -> dict:
    import time as _time
    readings = [
        SensorReading(
            ax=sample.ax,
            ay=sample.ay,
            az=sample.az,
            gx=sample.gx,
            gy=sample.gy,
            gz=sample.gz,
            speed_kmh=sample.speedKmh,
        )
        for sample in payload.samples
    ]
    _start = _time.time()
    result = analyzer.analyze(readings)
    elapsed_ms = round((_time.time() - _start) * 1000, 2)
    global _inference_count, _last_inference_ms
    _inference_count += 1
    _last_inference_ms = elapsed_ms
    _inference_stats["total_inferences"] += 1
    _inference_stats["total_ms"] += elapsed_ms
    if result.get("crashDetected"):
        _inference_stats["crash_detections"] += 1
    return result


_false_positive_count: int = 0


@app.get("/metrics")
def metrics() -> dict:
    total = _inference_stats["total_inferences"]
    crash_detections = _inference_stats["crash_detections"]
    avg_ms = round(_inference_stats["total_ms"] / total, 2) if total > 0 else 0.0
    false_positive_rate = round(_false_positive_count / max(crash_detections, 1), 4)
    # Drift alert: FP rate > 20 % or avg inference > 200 ms suggests model degradation.
    drift_alert = false_positive_rate > 0.20 or avg_ms > 200
    return {
        "total_inferences": total,
        "crash_detections": crash_detections,
        "false_positives_logged": _false_positive_count,
        "false_positive_rate": false_positive_rate,
        "avg_inference_ms": avg_ms,
        "model_runtime": analyzer.runtime_name,
        "model_loaded": analyzer.is_model_loaded,
        "drift_alert": drift_alert,
        "retraining_recommended": drift_alert,
    }


@app.post("/metrics/false-positive")
def log_false_positive_endpoint() -> dict:
    global _false_positive_count
    _false_positive_count += 1
    analyzer.log_false_positive(0.0, 0.0)
    return {"logged": True, "total_false_positives": _false_positive_count}


_ADMIN_TOKEN = os.getenv("RETRAIN_ADMIN_TOKEN", "")


@app.post("/retrain")
def trigger_retrain(x_admin_token: str = Header(default="")) -> dict:
    """Admin-only endpoint: launch retrain.py as a subprocess and return immediately."""
    if not _ADMIN_TOKEN or x_admin_token != _ADMIN_TOKEN:
        raise HTTPException(status_code=403, detail="Forbidden")
    training_script = os.path.join(os.path.dirname(__file__), "..", "training", "retrain.py")
    if not os.path.exists(training_script):
        raise HTTPException(status_code=404, detail="Training script not found")
    subprocess.Popen(
        [sys.executable, training_script],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return {"status": "retrain_started", "script": training_script}


@app.get("/ai/stats")
def ai_stats() -> dict:
    total = _inference_stats["total_inferences"]
    avg_ms = round(_inference_stats["total_ms"] / total, 2) if total > 0 else 0.0
    return {
        "model_loaded": analyzer.is_model_loaded,
        "model_path": analyzer.model_path.name,
        "inference_count": _inference_count,
        "last_inference_ms": _last_inference_ms,
        "fallback_active": not analyzer.is_model_loaded,
        # legacy fields kept for backward compatibility
        "total_inferences": total,
        "crash_detections": _inference_stats["crash_detections"],
        "avg_inference_ms": avg_ms,
        "model_status": "loaded" if analyzer.is_model_loaded else "fallback",
    }
