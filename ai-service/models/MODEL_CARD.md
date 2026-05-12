# SafePulse Crash Detection Model Card

## Model Overview

| Field | Value |
|---|---|
| **Model name** | SafePulse Crash Detector |
| **Version** | 1.0 |
| **Format** | TensorFlow Lite (`.tflite`) |
| **Runtime** | `tflite-runtime 2.14.0` (server) · `tflite_flutter` (on-device) |
| **Input shape** | `[1, 250, 6]` — batch × timesteps × features |
| **Output shape** | `[1, 1]` — crash probability (0.0 – 1.0) |
| **Threshold** | `> 0.25` → crash confirmed |

## Input Features (per timestep)

| Index | Feature | Unit |
|---|---|---|
| 0 | Accelerometer X (`ax`) | m/s² |
| 1 | Accelerometer Y (`ay`) | m/s² |
| 2 | Accelerometer Z (`az`) | m/s² |
| 3 | Gyroscope X (`gx`) | rad/s |
| 4 | Gyroscope Y (`gy`) | rad/s |
| 5 | Gyroscope Z (`gz`) | rad/s |

Sensor data is sampled at **50 Hz**; 250 samples = 5 seconds of sliding window.

## Architecture

LSTM-based sequence classifier:
- `LSTM(64, return_sequences=True)` → `LSTM(32)` → `Dense(1, sigmoid)`
- Trained on synthetic crash signatures augmented with phone-drop and road-bump patterns.

## Performance

| Metric | Value |
|---|---|
| Precision | ~0.87 (estimated, synthetic data) |
| Recall | ~0.91 (estimated, synthetic data) |
| Avg inference time (CPU) | < 50 ms |
| Phone-drop false positive rate | < 5 % (heuristic filter applied) |

## Limitations

- Trained on **synthetic** data only; real-world precision/recall will differ.
- Does not account for vehicle type (motorcycle, truck) or road surface.
- The heuristic fallback (G-force threshold) activates when the model is unavailable.

## Retraining

Use `training/retrain.py` to retrain with new data and export a fresh `.tflite` model.  
Trigger via the admin API endpoint `POST /retrain` (requires `RETRAIN_ADMIN_TOKEN`).

## Drift Detection

The `/metrics` endpoint exposes `drift_alert` and `retraining_recommended` flags.  
Retraining is recommended when the false-positive rate exceeds 20 % or average  
inference time exceeds 200 ms.
