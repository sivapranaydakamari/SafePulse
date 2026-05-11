import logging

from fastapi import FastAPI

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
    return analyzer.analyze(readings)
