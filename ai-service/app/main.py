import hashlib
import json
import logging
import os
import pathlib
import subprocess
import sys
import time as _time
from typing import Generator

from fastapi import FastAPI, HTTPException, Header
from fastapi.responses import StreamingResponse

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
    """
    Return runtime inference statistics merged with the latest training metrics.json
    (if present). Includes a drift_alert flag when FP rate exceeds 20 % or average
    inference latency exceeds 200 ms.
    """
    total = _inference_stats["total_inferences"]
    crash_detections = _inference_stats["crash_detections"]
    avg_ms = round(_inference_stats["total_ms"] / total, 2) if total > 0 else 0.0
    false_positive_rate = round(_false_positive_count / max(crash_detections, 1), 4)
    drift_alert = false_positive_rate > 0.20 or avg_ms > 200

    # Merge with latest training metrics.json if available
    metrics_json_path = pathlib.Path(__file__).parent.parent / "training" / "output" / "metrics.json"
    training_metrics: dict = {}
    if metrics_json_path.exists():
        try:
            training_metrics = json.loads(metrics_json_path.read_text())
        except (json.JSONDecodeError, OSError):
            pass

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
        "training_metrics": training_metrics,
    }


@app.post("/metrics/false-positive")
def log_false_positive_endpoint() -> dict:
    global _false_positive_count
    _false_positive_count += 1
    analyzer.log_false_positive(0.0, 0.0)
    return {"logged": True, "total_false_positives": _false_positive_count}


_ADMIN_TOKEN = os.getenv("RETRAIN_ADMIN_TOKEN", "")


def _stream_retrain_output(script_path: str) -> Generator[str, None, None]:
    """Run retrain.py as a subprocess and yield stdout lines as SSE events."""
    yield "data: {\"status\": \"started\"}\n\n"
    proc = subprocess.Popen(
        [sys.executable, script_path],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        line = line.rstrip("\n")
        if line:
            payload = json.dumps({"log": line})
            yield f"data: {payload}\n\n"
    proc.wait()
    exit_code = proc.returncode
    status = "completed" if exit_code == 0 else "failed"
    yield f"data: {json.dumps({'status': status, 'exit_code': exit_code})}\n\n"


@app.post("/retrain")
def trigger_retrain(x_admin_token: str = Header(default="")) -> StreamingResponse:
    """
    Admin-only endpoint — triggers retrain.py and streams stdout back as
    Server-Sent Events so the caller can monitor training progress in real time.

    Authentication: supply the RETRAIN_ADMIN_TOKEN env var value in the
    X-Admin-Token request header.
    """
    if not _ADMIN_TOKEN or x_admin_token != _ADMIN_TOKEN:
        raise HTTPException(status_code=403, detail="Forbidden")
    training_script = os.path.join(os.path.dirname(__file__), "..", "training", "retrain.py")
    if not os.path.exists(training_script):
        raise HTTPException(status_code=404, detail="Training script not found")
    return StreamingResponse(
        _stream_retrain_output(training_script),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@app.get("/model/version")
def model_version() -> dict:
    """
    Return the current model's SHA-256 hash and training date.

    The hash is computed from the on-disk crash_model.tflite file so that
    callers can detect whether the model has been hot-swapped after a retrain.
    Training date is read from training/output/metrics.json if available.
    """
    model_path = analyzer.model_path
    if not model_path.exists():
        return {
            "model_file": model_path.name,
            "sha256": None,
            "trained_at": None,
            "version": "unknown",
        }

    sha256 = hashlib.sha256(model_path.read_bytes()).hexdigest()

    trained_at: str | None = None
    metrics_json_path = pathlib.Path(__file__).parent.parent / "training" / "output" / "metrics.json"
    if metrics_json_path.exists():
        try:
            meta = json.loads(metrics_json_path.read_text())
            trained_at = meta.get("trained_at")
        except (json.JSONDecodeError, OSError):
            pass

    return {
        "model_file": model_path.name,
        "sha256": sha256,
        "trained_at": trained_at,
        "version": f"sha256:{sha256[:12]}",
    }


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
        "total_inferences": total,
        "crash_detections": _inference_stats["crash_detections"],
        "avg_inference_ms": avg_ms,
        "model_status": "loaded" if analyzer.is_model_loaded else "fallback",
    }
