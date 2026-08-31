import json
import os
from pathlib import Path

import cv2
import numpy as np

from minimap_calibration.contracts import Anchor
from minimap_calibration.detect import DetectParams, Roi, detect_corner_anchored_square


ROOT = Path(os.environ.get("APPDATA", ".")) / "GodSense" / "calibration-corpus"
ROOT.mkdir(parents=True, exist_ok=True)
WIDTH = 300
HEIGHT = 300


def main():
    rng = np.random.default_rng(886)
    metadata = []
    for index in range(36):
        size = (100, 140, 180)[index % 3]
        prior = size + ((index % 5) - 2) * 4
        frame = rng.integers(0, 20, (HEIGHT, WIDTH, 3), dtype=np.uint8)
        left = WIDTH - size
        top = HEIGHT - size
        cv2.rectangle(frame, (left, top), (WIDTH - 1, HEIGHT - 1), (220, 220, 220), 2)
        # Internal lane strokes should not win over edge-mass projection.
        cv2.line(frame, (left + 10, HEIGHT - 15), (WIDTH - 15, top + 10), (180, 180, 180), 1)
        cv2.line(frame, (left + size // 2, top + 8), (left + size // 2, HEIGHT - 8), (120, 120, 120), 1)
        bounds, confidence = detect_corner_anchored_square(
            frame,
            Roi(x=0, y=0, width=WIDTH, height=HEIGHT),
            anchor=Anchor.BOTTOM_RIGHT,
            prior_size=prior,
            params=DetectParams(),
        )
        stem = f"calibration-{index:04d}"
        (ROOT / f"{stem}.bgr").write_bytes(frame.tobytes())
        metadata.append(
            {
                "file": f"{stem}.bgr",
                "width": WIDTH,
                "height": HEIGHT,
                "prior_size": prior,
                "expected": bounds.as_mss_dict(),
                "confidence": float(confidence),
            }
        )
    (ROOT / "corpus.json").write_text(
        json.dumps(metadata, indent=2), encoding="utf-8"
    )
    print(f"Calibration corpus generated: {ROOT} ({len(metadata)} frames)")


if __name__ == "__main__":
    main()
