"""
SafePulse — Model Evaluation Harness

Loads crash_model.tflite and evaluates precision, recall, and F1 on a
held-out test dataset (CSV or auto-generated synthetic data).

Usage:
    # With a real CSV:
    python training/evaluate_model.py \
        --model app/crash_model.tflite \
        --data  training/accident_data.csv \
        --threshold 0.25

    # Synthetic test data (no CSV needed):
    python training/evaluate_model.py --model app/crash_model.tflite

Output:
    Prints a classification report and writes training/output/metrics.json.
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import sys
import time
from typing import List, Tuple

import numpy as np

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
TIMESTEPS = 250
FEATURES  = 6   # ax ay az gx gy gz
OUTPUT_DIR = pathlib.Path(__file__).parent / "output"


# ---------------------------------------------------------------------------
# TFLite loader (mirrors crash_analyzer.py strategy)
# ---------------------------------------------------------------------------

def _load_interpreter(model_path: str):
    path = pathlib.Path(model_path)
    if not path.exists():
        print(f"[evaluate] ERROR: model not found at {path}", file=sys.stderr)
        sys.exit(1)
    try:
        import tflite_runtime.interpreter as tflite  # type: ignore
    except ImportError:
        try:
            import tensorflow.lite as tflite  # type: ignore
        except ImportError:
            print("[evaluate] ERROR: neither tflite_runtime nor tensorflow is installed.", file=sys.stderr)
            sys.exit(1)
    interp = tflite.Interpreter(model_path=str(path))
    interp.allocate_tensors()
    return interp


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def _load_csv(csv_path: str) -> Tuple[np.ndarray, np.ndarray]:
    """
    Expects CSV columns: ax,ay,az,gx,gy,gz,label
    where label is 1 (crash) or 0 (no crash).
    Rows are grouped into sliding windows of TIMESTEPS rows per sample.
    """
    rows: List[List[float]] = []
    labels_raw: List[int] = []
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            features = [float(row[k]) for k in ("ax", "ay", "az", "gx", "gy", "gz")]
            rows.append(features)
            labels_raw.append(int(float(row.get("label", 0))))

    # Group into non-overlapping windows
    n_windows = len(rows) // TIMESTEPS
    if n_windows == 0:
        print(f"[evaluate] WARN: CSV has fewer than {TIMESTEPS} rows — using synthetic data.")
        return _synthetic_data(500)

    X = np.array(rows[: n_windows * TIMESTEPS], dtype=np.float32).reshape(n_windows, TIMESTEPS, FEATURES)
    y = np.array([labels_raw[i * TIMESTEPS] for i in range(n_windows)], dtype=np.int32)
    return X, y


def _synthetic_data(n_samples: int = 500) -> Tuple[np.ndarray, np.ndarray]:
    """Generate balanced synthetic crash / normal windows for evaluation."""
    rng = np.random.default_rng(seed=42)
    half = n_samples // 2
    crash_windows = []
    for _ in range(half):
        w = rng.normal(0, 0.5, (TIMESTEPS, FEATURES)).astype(np.float32)
        spike = rng.integers(50, 150)
        w[spike : spike + 10, :3] += rng.uniform(30, 70)
        crash_windows.append(w)
    normal_windows = rng.normal(0, 2.0, (half, TIMESTEPS, FEATURES)).astype(np.float32)
    X = np.concatenate([np.stack(crash_windows), normal_windows], axis=0)
    y = np.array([1] * half + [0] * half, dtype=np.int32)
    idx = rng.permutation(len(y))
    return X[idx], y[idx]


# ---------------------------------------------------------------------------
# Inference
# ---------------------------------------------------------------------------

def _run_inference(interp, X: np.ndarray) -> np.ndarray:
    input_idx  = interp.get_input_details()[0]["index"]
    output_idx = interp.get_output_details()[0]["index"]
    probs = np.zeros(len(X), dtype=np.float32)
    for i, window in enumerate(X):
        interp.set_tensor(input_idx, window[np.newaxis])
        interp.invoke()
        probs[i] = interp.get_tensor(output_idx)[0][0]
    return probs


# ---------------------------------------------------------------------------
# Metrics
# ---------------------------------------------------------------------------

def _compute_metrics(y_true: np.ndarray, y_pred: np.ndarray, threshold: float) -> dict:
    predicted = (y_pred >= threshold).astype(int)
    tp = int(np.sum((predicted == 1) & (y_true == 1)))
    fp = int(np.sum((predicted == 1) & (y_true == 0)))
    fn = int(np.sum((predicted == 0) & (y_true == 1)))
    tn = int(np.sum((predicted == 0) & (y_true == 0)))

    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall    = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1        = (2 * precision * recall / (precision + recall)) if (precision + recall) > 0 else 0.0
    accuracy  = (tp + tn) / len(y_true) if len(y_true) > 0 else 0.0

    return {
        "threshold": threshold,
        "precision": round(precision, 4),
        "recall":    round(recall, 4),
        "f1":        round(f1, 4),
        "accuracy":  round(accuracy, 4),
        "tp": tp, "fp": fp, "fn": fn, "tn": tn,
        "n_samples": int(len(y_true)),
    }


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate SafePulse crash detection model")
    parser.add_argument(
        "--model",
        default=str(pathlib.Path(__file__).parent.parent / "app" / "crash_model.tflite"),
        help="Path to .tflite model file",
    )
    parser.add_argument("--data",      default=None,  help="Path to accident_data.csv (optional)")
    parser.add_argument("--threshold", type=float, default=0.25, help="Classification threshold")
    parser.add_argument("--output",    default=str(OUTPUT_DIR / "metrics.json"), help="Output metrics JSON path")
    args = parser.parse_args()

    print(f"[evaluate] Loading model: {args.model}")
    interp = _load_interpreter(args.model)

    if args.data and pathlib.Path(args.data).exists():
        print(f"[evaluate] Loading dataset: {args.data}")
        X, y = _load_csv(args.data)
    else:
        print("[evaluate] No CSV provided — using synthetic test data.")
        X, y = _synthetic_data(500)

    print(f"[evaluate] Running inference on {len(X)} samples...")
    t0 = time.perf_counter()
    probs = _run_inference(interp, X)
    elapsed_ms = (time.perf_counter() - t0) * 1000

    metrics = _compute_metrics(y, probs, args.threshold)
    metrics["avg_inference_ms"] = round(elapsed_ms / len(X), 3)
    metrics["model_path"] = str(args.model)

    print("\n── Evaluation Results ─────────────────────────────")
    print(f"  Threshold : {metrics['threshold']}")
    print(f"  Precision : {metrics['precision']:.1%}")
    print(f"  Recall    : {metrics['recall']:.1%}")
    print(f"  F1 Score  : {metrics['f1']:.1%}")
    print(f"  Accuracy  : {metrics['accuracy']:.1%}")
    print(f"  TP={metrics['tp']} FP={metrics['fp']} FN={metrics['fn']} TN={metrics['tn']}")
    print(f"  Avg inference: {metrics['avg_inference_ms']} ms/sample")
    print("────────────────────────────────────────────────────\n")

    out_path = pathlib.Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(metrics, indent=2))
    print(f"[evaluate] Metrics saved → {out_path}")


if __name__ == "__main__":
    main()
