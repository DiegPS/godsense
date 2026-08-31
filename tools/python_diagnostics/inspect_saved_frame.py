import json
import os
from pathlib import Path

import cv2
import numpy as np

from cv_tracker.utils import compute_face_hist, get_inner_face_crop


root = Path(os.environ["APPDATA"]) / "GodSense" / "cv-corpus"
meta = json.loads((root / "frame-000001.json").read_text(encoding="utf-8"))
detection = meta["detections"][0]
name = detection["name"]
size = meta["icon_size"]
x1, y1, x2, y2 = detection["box"]
frame = cv2.imread(str(root / "frame-000001.png"), cv2.IMREAD_COLOR)
raw_frame = np.frombuffer(
    (root / "frame-000001.bgr").read_bytes(), dtype=np.uint8
).reshape((300, 300, 3))
target = cv2.resize(
    cv2.imread(str(root / meta["target_icons"][name]), cv2.IMREAD_COLOR),
    (size, size),
)
raw_target = np.frombuffer(
    (root / "targets_resized" / f"{name}.bgr").read_bytes(), dtype=np.uint8
).reshape((28, 28, 3))
live_face = get_inner_face_crop(frame[y1:y2, x1:x2], size=size)
target_face = get_inner_face_crop(target, size=size)
tm = cv2.minMaxLoc(
    cv2.matchTemplate(live_face, target_face, cv2.TM_CCOEFF_NORMED)
)[1]
hist = cv2.compareHist(
    compute_face_hist(live_face),
    compute_face_hist(target_face),
    cv2.HISTCMP_CORREL,
)
mae = float(np.mean(np.abs(live_face.astype(np.int16) - target_face.astype(np.int16))))
raw_live_face = get_inner_face_crop(raw_frame[y1:y2, x1:x2], size=size)
raw_mae = float(
    np.mean(np.abs(raw_live_face.astype(np.int16) - target_face.astype(np.int16)))
)
raw_target_mae = float(
    np.mean(np.abs(raw_target.astype(np.int16) - target.astype(np.int16)))
)
print(
    json.dumps(
        {
            "name": name,
            "mae": mae,
            "raw_mae": raw_mae,
            "raw_target_mae": raw_target_mae,
            "tm": tm,
            "hist": hist,
            "raw_live_pixel_rel_5_4": raw_frame[y1 + 4, x1 + 5].tolist(),
            "target_pixel_rel_5_4": raw_target[4, 5].tolist(),
            "live_face_pixel_1_0": raw_live_face[0, 1].tolist(),
            "target_face_pixel_1_0": target_face[0, 1].tolist(),
        }
    )
)
