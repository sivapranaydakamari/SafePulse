"""
SafePulse crash-detection model retraining pipeline.

Generates synthetic crash/non-crash sensor windows, trains an LSTM classifier,
and exports a TFLite model to ai-service/app/crash_model.tflite.

Usage:
    python training/retrain.py [--epochs 20] [--samples 2000] [--output PATH]

Triggered automatically via:
    POST /retrain  (admin-auth, spawns this script as a subprocess)
"""

import argparse
import pathlib
import struct
import numpy as np

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Retrain SafePulse crash detector")
    p.add_argument("--epochs",  type=int, default=20,   help="Training epochs")
    p.add_argument("--samples", type=int, default=2000, help="Total training samples")
    p.add_argument(
        "--output",
        type=str,
        default=str(pathlib.Path(__file__).parent.parent / "app" / "crash_model.tflite"),
        help="Output .tflite path",
    )
    return p.parse_args()


# ---------------------------------------------------------------------------
# Synthetic data generation
# ---------------------------------------------------------------------------
TIMESTEPS = 250
FEATURES  = 6   # ax ay az gx gy gz


def _generate_crash_window() -> np.ndarray:
    """Simulate a crash: sudden high-G spike in the first half of the window."""
    window = np.random.randn(TIMESTEPS, FEATURES).astype(np.float32) * 0.5
    spike_start = np.random.randint(50, 150)
    spike_len   = np.random.randint(5, 20)
    window[spike_start : spike_start + spike_len, :3] += np.random.uniform(30, 80)
    return window


def _generate_normal_window() -> np.ndarray:
    """Simulate normal driving: low-G, smooth motion."""
    return (np.random.randn(TIMESTEPS, FEATURES) * 2.0).astype(np.float32)


def _build_dataset(n_samples: int):
    half = n_samples // 2
    X = np.stack(
        [_generate_crash_window() for _ in range(half)]
        + [_generate_normal_window() for _ in range(half)]
    )
    y = np.array([1] * half + [0] * half, dtype=np.float32)
    idx = np.random.permutation(len(y))
    return X[idx], y[idx]


# ---------------------------------------------------------------------------
# Model definition, training, and TFLite export
# ---------------------------------------------------------------------------

def _train_and_export(epochs: int, n_samples: int, output_path: str) -> None:
    try:
        import tensorflow as tf  # type: ignore
    except ImportError:
        print("[retrain] TensorFlow not installed. Install training/requirements-training.txt.")
        raise

    print(f"[retrain] Generating {n_samples} synthetic samples …")
    X, y = _build_dataset(n_samples)

    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(TIMESTEPS, FEATURES)),
        tf.keras.layers.LSTM(64, return_sequences=True),
        tf.keras.layers.LSTM(32),
        tf.keras.layers.Dense(1, activation="sigmoid"),
    ])
    model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["accuracy"])
    print(f"[retrain] Training for {epochs} epochs …")
    model.fit(X, y, epochs=epochs, batch_size=32, validation_split=0.15, verbose=1)

    # Export to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    out = pathlib.Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(tflite_model)
    print(f"[retrain] Model saved → {out}  ({len(tflite_model):,} bytes)")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    args = _parse_args()
    _train_and_export(args.epochs, args.samples, args.output)
