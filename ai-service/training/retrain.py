"""
SafePulse crash-detection model retraining pipeline.

Loads accident_data.csv (if present) or generates synthetic training data,
trains an LSTM crash-detection classifier, exports a versioned TFLite model,
and writes training/output/metrics.json with precision/recall/F1.

Usage:
    python training/retrain.py [--epochs 20] [--samples 2000] [--data PATH] [--output PATH]

Triggered automatically via:
    POST /retrain  (admin-auth, spawns this script as a subprocess)
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import sys
from datetime import datetime, timezone
from typing import List, Tuple

import numpy as np

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
TIMESTEPS = 250
FEATURES  = 6   # ax ay az gx gy gz
OUTPUT_DIR = pathlib.Path(__file__).parent / "output"


# ---------------------------------------------------------------------------
# Data helpers
# ---------------------------------------------------------------------------

def _load_csv(csv_path: str, test_split: float = 0.2) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    Load accident_data.csv with columns: ax,ay,az,gx,gy,gz,label
    Groups rows into non-overlapping windows of TIMESTEPS.
    Returns (X_train, y_train, X_test, y_test).
    """
    rows: List[List[float]] = []
    labels_raw: List[int] = []
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            feat = [float(row[k]) for k in ("ax", "ay", "az", "gx", "gy", "gz")]
            rows.append(feat)
            labels_raw.append(int(float(row.get("label", 0))))

    n_windows = len(rows) // TIMESTEPS
    if n_windows < 10:
        print(f"[retrain] WARN: CSV has only {n_windows} windows (<10) — supplementing with synthetic data.")
        return _synthetic_split(2000, test_split)

    X = np.array(rows[: n_windows * TIMESTEPS], dtype=np.float32).reshape(n_windows, TIMESTEPS, FEATURES)
    y = np.array([labels_raw[i * TIMESTEPS] for i in range(n_windows)], dtype=np.float32)
    idx = np.random.permutation(len(y))
    X, y = X[idx], y[idx]
    split = int(len(X) * (1 - test_split))
    return X[:split], y[:split], X[split:], y[split:]


def _generate_crash_window(rng: np.random.Generator) -> np.ndarray:
    window = rng.normal(0, 0.5, (TIMESTEPS, FEATURES)).astype(np.float32)
    spike_start = int(rng.integers(50, 150))
    spike_len   = int(rng.integers(5, 20))
    window[spike_start : spike_start + spike_len, :3] += rng.uniform(30, 80)
    return window


def _generate_normal_window(rng: np.random.Generator) -> np.ndarray:
    return rng.normal(0, 2.0, (TIMESTEPS, FEATURES)).astype(np.float32)


def _synthetic_split(
    n_samples: int, test_split: float = 0.2
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    rng = np.random.default_rng()
    half = n_samples // 2
    X = np.stack(
        [_generate_crash_window(rng) for _ in range(half)]
        + [_generate_normal_window(rng) for _ in range(half)]
    )
    y = np.array([1.0] * half + [0.0] * half, dtype=np.float32)
    idx = rng.permutation(len(y))
    X, y = X[idx], y[idx]
    split = int(len(X) * (1 - test_split))
    return X[:split], y[:split], X[split:], y[split:]


# ---------------------------------------------------------------------------
# Metrics
# ---------------------------------------------------------------------------

def _compute_metrics(y_true: np.ndarray, probs: np.ndarray, threshold: float = 0.25) -> dict:
    predicted = (probs >= threshold).astype(int)
    y_int = y_true.astype(int)
    tp = int(np.sum((predicted == 1) & (y_int == 1)))
    fp = int(np.sum((predicted == 1) & (y_int == 0)))
    fn = int(np.sum((predicted == 0) & (y_int == 1)))
    tn = int(np.sum((predicted == 0) & (y_int == 0)))
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall    = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1        = (2 * precision * recall / (precision + recall)) if (precision + recall) > 0 else 0.0
    return {
        "threshold": threshold,
        "precision": round(precision, 4),
        "recall":    round(recall, 4),
        "f1":        round(f1, 4),
        "tp": tp, "fp": fp, "fn": fn, "tn": tn,
        "n_test_samples": int(len(y_true)),
    }


# ---------------------------------------------------------------------------
# Training + TFLite export
# ---------------------------------------------------------------------------

def _train_and_export(
    X_train: np.ndarray,
    y_train: np.ndarray,
    X_test: np.ndarray,
    y_test: np.ndarray,
    epochs: int,
    output_path: str,
) -> dict:
    try:
        import tensorflow as tf  # type: ignore
    except ImportError:
        print("[retrain] TensorFlow not installed. Run: pip install -r training/requirements-training.txt")
        sys.exit(1)

    print(f"[retrain] Training set: {len(X_train)} samples | Test set: {len(X_test)} samples")

    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(TIMESTEPS, FEATURES)),
        tf.keras.layers.LSTM(64, return_sequences=True),
        tf.keras.layers.LSTM(32),
        tf.keras.layers.Dense(1, activation="sigmoid"),
    ])
    model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["accuracy"])
    model.summary()

    print(f"[retrain] Training for {epochs} epochs...")
    model.fit(
        X_train, y_train,
        epochs=epochs,
        batch_size=32,
        validation_split=0.15,
        verbose=1,
    )

    # Evaluate on held-out test set
    probs = model.predict(X_test, verbose=0).flatten()
    metrics = _compute_metrics(y_test, probs)
    print(f"[retrain] Test precision={metrics['precision']:.1%} recall={metrics['recall']:.1%} F1={metrics['f1']:.1%}")

    # Export TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_bytes = converter.convert()
    out = pathlib.Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(tflite_bytes)
    print(f"[retrain] Model saved → {out}  ({len(tflite_bytes):,} bytes)")

    return metrics


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Retrain SafePulse crash detector")
    p.add_argument("--epochs",  type=int, default=20,   help="Training epochs (default: 20)")
    p.add_argument("--samples", type=int, default=2000, help="Synthetic samples when no CSV (default: 2000)")
    p.add_argument("--data",    default=None,            help="Path to accident_data.csv (optional)")
    p.add_argument(
        "--output",
        default=None,
        help="Output .tflite path (default: training/output/crash_model_v<timestamp>.tflite)",
    )
    return p.parse_args()


if __name__ == "__main__":
    args = _parse_args()

    timestamp = datetime.now(tz=timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    default_output = str(OUTPUT_DIR / f"crash_model_v{timestamp}.tflite")
    tflite_path = args.output or default_output

    # Also update the canonical model path used by the server
    canonical_path = str(pathlib.Path(__file__).parent.parent / "app" / "crash_model.tflite")

    csv_path = args.data or str(pathlib.Path(__file__).parent / "accident_data.csv")
    if pathlib.Path(csv_path).exists():
        print(f"[retrain] Loading CSV: {csv_path}")
        X_train, y_train, X_test, y_test = _load_csv(csv_path)
    else:
        print(f"[retrain] No CSV at {csv_path} — generating {args.samples} synthetic samples.")
        X_train, y_train, X_test, y_test = _synthetic_split(args.samples)

    metrics = _train_and_export(X_train, y_train, X_test, y_test, args.epochs, tflite_path)

    # Copy versioned model to canonical path so the server picks it up
    import shutil
    shutil.copy2(tflite_path, canonical_path)
    print(f"[retrain] Canonical model updated → {canonical_path}")

    # Write metrics.json
    metrics["model_path"] = tflite_path
    metrics["trained_at"] = timestamp
    metrics_path = OUTPUT_DIR / "metrics.json"
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    metrics_path.write_text(json.dumps(metrics, indent=2))
    print(f"[retrain] Metrics saved → {metrics_path}")
    print("[retrain] Done.")
