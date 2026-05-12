# SafePulse AI — Model Roadmap

## Current State (v1.0)

SafePulse ships a static LSTM TFLite model trained on synthetic crash signatures.  
The model runs on-device (`tflite_flutter`) and is validated server-side (`tflite-runtime` in FastAPI).

| Dimension | Current | Target |
|-----------|---------|--------|
| Training data | Synthetic (2 000 windows) | Real accident dataset + synthetic augmentation |
| Model update | Manual `POST /retrain` | Continuous retraining pipeline |
| Personalisation | None | On-device fine-tuning per driver profile |
| Input modalities | IMU only (ax/ay/az/gx/gy/gz) | IMU + GPS speed + weather + road type |

---

## Phase A — Continuous Retraining (3–6 months)

**Goal:** Replace manual retraining with an automated pipeline triggered by drift detection.

1. **Drift monitor** (`ai-service/app/drift_monitor.py`) tracks the 7-day rolling false-positive rate.
2. When FP rate exceeds the configurable threshold (`DRIFT_FP_THRESHOLD`, default 0.20), a `WARNING` log is emitted and a Firestore alert is written to `admin/drift_alerts`.
3. A Cloud Scheduler job (or GitHub Actions scheduled workflow) calls `POST /retrain` when a drift alert is active.
4. The retrain pipeline (`training/retrain.py`) loads `accident_data.csv`, produces a versioned `crash_model_v{timestamp}.tflite`, writes `training/output/metrics.json`, and hot-swaps the model in the running FastAPI process.
5. Metrics (precision, recall, F1) are written to `/metrics` and compared against the previous model before promotion.

**Key files:**
- `ai-service/app/drift_monitor.py`
- `ai-service/training/retrain.py`
- `ai-service/training/evaluate_model.py`
- `ai-service/training/output/metrics.json`

---

## Phase B — Federated Learning (6–12 months)

**Goal:** Improve model accuracy using anonymised crash events from consenting users without centralising raw sensor data.

1. Each device records a crash window and outcome (confirmed crash vs. false positive) in `EmergencyRecorderService`.
2. A differential-privacy gradient aggregator (TensorFlow Federated or PySyft) collects model weight deltas — never raw data — from opted-in devices.
3. The global model is updated on a weekly cadence; only aggregate gradients leave the device.
4. All participant data is hashed with a per-device salt before transmission; no PII is collected.

**Privacy commitment:** Federated participation is opt-in, opt-out at any time, and the aggregated model update contains no information attributable to individual users (ε-differential privacy, ε ≤ 1.0).

---

## Phase C — Multi-Modal Fusion (12–18 months)

**Goal:** Reduce false positives caused by speed bumps, potholes, and phone drops by fusing additional signal sources.

| Input | Source | Benefit |
|-------|--------|---------|
| GPS speed derivative | `LocationService` | Distinguishes true deceleration from bump |
| Road surface type | OpenStreetMap tags | Flags known rough-road segments |
| Weather severity | Open-Meteo API | Contextualises rain-related loss of control |
| OBD-II vehicle speed | `OBDService` (Phase 2) | Ground-truth speed vs GPS estimate |

**Architecture change:** The model input grows from `[1, 250, 6]` to `[1, 250, 10]` (adding GPS Δspeed, road_type_encoded, weather_severity, obd_speed).  
The existing `FeatureFlags.advancedAiEnabled` gate controls the multi-modal input path.

---

## Evaluation Harness

Run `training/evaluate_model.py` to print precision/recall/F1 for the current model on the held-out test split of `accident_data.csv`.

```bash
cd ai-service
python training/evaluate_model.py \
  --model app/crash_model.tflite \
  --data training/accident_data.csv \
  --threshold 0.25
```

Output is written to `training/output/metrics.json`.
