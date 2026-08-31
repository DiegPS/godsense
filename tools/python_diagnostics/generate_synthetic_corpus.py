import json
import os
import shutil
import time
import urllib.request
from pathlib import Path

import cv2
import numpy as np

from cv_tracker.config import DEFAULT_SETTINGS
from cv_tracker.detector import HSVRedRingDetector
from cv_tracker.models import ChampionPosition
from cv_tracker.scorer import score_and_assign
from cv_tracker.utils import build_target_info


ROOT = Path(os.environ.get("APPDATA", ".")) / "GodSense" / "cv-corpus"
TARGETS = ROOT / "targets"
RESIZED_TARGETS = ROOT / "targets_resized"
ROOT.mkdir(parents=True, exist_ok=True)
TARGETS.mkdir(exist_ok=True)
RESIZED_TARGETS.mkdir(exist_ok=True)
ICON_SIZE = 28
FRAME_SIZE = 300
CHAMPIONS = ("Sona", "Sion", "Udyr")
VERSION = "16.17.1"


def icon(name):
    path = TARGETS / f"{name}.png"
    if not path.exists():
        urllib.request.urlretrieve(
            f"https://ddragon.leagueoflegends.com/cdn/{VERSION}/img/champion/{name}.png",
            path,
        )
    return path


def main():
    for old in ROOT.glob("frame-*.png"):
        old.unlink()
    for old in ROOT.glob("frame-*.json"):
        old.unlink()

    paths = {name: icon(name) for name in CHAMPIONS}
    targets = [
        build_target_info(name, str(path), ICON_SIZE, 36)
        for name, path in paths.items()
    ]
    targets = [target for target in targets if target is not None]
    detector = HSVRedRingDetector(
        (FRAME_SIZE, FRAME_SIZE, 3),
        ICON_SIZE,
        DEFAULT_SETTINGS.vision,
    )
    rng = np.random.default_rng(527)
    red_hsv = np.uint8([[[3, 255, 255]]])
    red_bgr = tuple(int(value) for value in cv2.cvtColor(red_hsv, cv2.COLOR_HSV2BGR)[0, 0])
    icons = {
        name: cv2.resize(cv2.imread(str(path)), (ICON_SIZE, ICON_SIZE))
        for name, path in paths.items()
    }
    resized_paths = {}
    resized_raw_paths = {}
    for name, image in icons.items():
        path = RESIZED_TARGETS / f"{name}.bmp"
        cv2.imwrite(str(path), image)
        resized_paths[name] = path
        raw_path = RESIZED_TARGETS / f"{name}.bgr"
        raw_path.write_bytes(image.tobytes())
        resized_raw_paths[name] = raw_path

    for index in range(120):
        frame = rng.integers(5, 45, (FRAME_SIZE, FRAME_SIZE, 3), dtype=np.uint8)
        placements = []
        count = index % 4
        for champion_index in range(count):
            name = CHAMPIONS[(index + champion_index) % len(CHAMPIONS)]
            x = 24 + ((index * 17 + champion_index * 71) % (FRAME_SIZE - ICON_SIZE - 48))
            y = 24 + ((index * 23 + champion_index * 53) % (FRAME_SIZE - ICON_SIZE - 48))
            frame[y : y + ICON_SIZE, x : x + ICON_SIZE] = icons[name]
            cv2.circle(
                frame,
                (x + ICON_SIZE // 2, y + ICON_SIZE // 2),
                ICON_SIZE // 2 - 1,
                red_bgr,
                2,
            )
            placements.append((name, x, y))

        # Solid red artifacts exercise the turret/core filter.
        if index % 3 == 0:
            cv2.circle(frame, (260, 35 + index % 100), 8, red_bgr, -1)

        raw = detector.detect(frame)
        state = {target.name: ChampionPosition() for target in targets}
        detections = score_and_assign(
            raw,
            targets,
            frame,
            state,
            DEFAULT_SETTINGS.tracker,
            ICON_SIZE,
            current_time=1000.0 + index / 6,
        )
        stem = f"frame-{index:06d}"
        cv2.imwrite(str(ROOT / f"{stem}.png"), frame)
        (ROOT / f"{stem}.bgr").write_bytes(frame.tobytes())
        expected = {
            "timestamp": 1000.0 + index / 6,
            "shape": [FRAME_SIZE, FRAME_SIZE],
            "targets": [target.name for target in targets],
            "target_icons": {
                name: str(path.relative_to(ROOT))
                for name, path in resized_paths.items()
            },
            "target_original": {
                name: str(path.relative_to(ROOT)) for name, path in paths.items()
            },
            "target_raw": {
                name: str(path.relative_to(ROOT))
                for name, path in resized_raw_paths.items()
            },
            "icon_size": ICON_SIZE,
            "placements": [
                {"name": name, "x": x, "y": y} for name, x, y in placements
            ],
            "detections": [
                {
                    "box": [int(value) for value in item.box],
                    "kind": item.kind,
                    "name": item.name,
                    "confidence": float(item.conf),
                    "template_score": float(item.tm_score),
                    "histogram_score": float(item.hist_score),
                }
                for item in detections
            ],
        }
        (ROOT / f"{stem}.json").write_text(
            json.dumps(expected, ensure_ascii=False),
            encoding="utf-8",
        )
    print(f"Synthetic corpus generated: {ROOT} (120 frames)")


if __name__ == "__main__":
    main()
