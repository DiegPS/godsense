import argparse
import ctypes
import json
import os
import shutil
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import sitecustomize  # Installs the PyInstaller .pyd finder before NumPy.
import cv2

import cv_tracker.engine as engine_module
from cv_tracker.config import DEFAULT_SETTINGS
from cv_tracker.engine import TrackerEngine
from cv_tracker.extractor import MinimapExtractor
from cv_tracker.models import CaptureRegion
from cv_tracker.utils import build_target_info


class _ProcessMemoryCounters(ctypes.Structure):
    _fields_ = [
        ("cb", ctypes.c_ulong),
        ("PageFaultCount", ctypes.c_ulong),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
    ]


def working_set_bytes():
    counters = _ProcessMemoryCounters()
    counters.cb = ctypes.sizeof(counters)
    process = ctypes.windll.kernel32.GetCurrentProcess()
    if ctypes.windll.psapi.GetProcessMemoryInfo(
        process, ctypes.byref(counters), counters.cb
    ):
        return int(counters.WorkingSetSize)
    return 0


def fetch_json(url):
    with urllib.request.urlopen(url, timeout=3) as response:
        return json.load(response)


class Diagnostics:
    def __init__(self, backend_url, data_dir, record_dir=None, record_every=6):
        self.backend_url = backend_url.rstrip("/")
        self.icon_dir = Path(data_dir) / "icons"
        self.icon_dir.mkdir(parents=True, exist_ok=True)
        self.lock = threading.Lock()
        self.snapshot = {"status": "waiting", "metrics": {}, "detections": []}
        self.images = {}
        self.stop = threading.Event()
        self.engine = None
        self.signature = None
        self.timings = {}
        self.samples = []
        self.record_dir = Path(record_dir) if record_dir else None
        self.record_every = max(1, int(record_every))
        self.record_index = 0
        self.target_icon_paths = {}
        if self.record_dir:
            self.record_dir.mkdir(parents=True, exist_ok=True)
        self.last_cpu_time = time.process_time()
        self.last_wall_time = time.perf_counter()

    def rebuild(self, state, calibration):
        bounds = calibration.get("bounds")
        icon_size = int(calibration.get("icon_size") or 28)
        if not bounds:
            return False
        active = state.get("active_player") or {}
        local_role = str(active.get("role") or "").upper()
        wanted = {"JUNGLE", "MIDDLE", "UTILITY", local_role}
        enemies = state.get("enemies") or []
        tracked = [p for p in enemies if str(p.get("role") or "").upper() in wanted]
        if not tracked:
            tracked = enemies
        roster = [(str(p.get("champion_name") or ""), str(p.get("icon_url") or "")) for p in tracked]
        signature = (tuple(bounds.get(k) for k in ("top", "left", "width", "height")), icon_size, tuple(roster))
        if signature == self.signature:
            return True

        targets = []
        target_icon_paths = {}
        for name, url in roster:
            if not name or not url:
                continue
            path = self.icon_dir / ("".join(c if c.isalnum() else "_" for c in name) + ".png")
            if not path.exists():
                try:
                    urllib.request.urlretrieve(url, path)
                except Exception:
                    continue
            target = build_target_info(name, str(path), icon_size, 36)
            if target is not None:
                targets.append(target)
                target_icon_paths[name] = str(path)
        if not targets:
            return False

        if self.engine is not None:
            try:
                self.engine.extractor.close()
            except Exception:
                pass
        region = CaptureRegion(
            top=int(bounds["top"]),
            left=int(bounds["left"]),
            width=int(bounds["width"]),
            height=int(bounds["height"]),
        )
        extractor = MinimapExtractor(region, icon_size)
        tracker = TrackerEngine(extractor, targets, DEFAULT_SETTINGS)
        tracker.initialize()
        self.engine = tracker
        self.target_icon_paths = target_icon_paths
        self.signature = signature
        self._instrument(tracker)
        return True

    def _instrument(self, tracker):
        original_grab = tracker.extractor.grab_minimap
        original_detect = tracker._detector.detect
        original_score = engine_module.score_and_assign

        def grab():
            started = time.perf_counter_ns()
            result = original_grab()
            self.timings["capture_ms"] = (time.perf_counter_ns() - started) / 1e6
            return result

        def detect(frame):
            started = time.perf_counter_ns()
            result = original_detect(frame)
            self.timings["detect_ms"] = (time.perf_counter_ns() - started) / 1e6
            return result

        def score(*args, **kwargs):
            started = time.perf_counter_ns()
            result = original_score(*args, **kwargs)
            self.timings["score_ms"] = (time.perf_counter_ns() - started) / 1e6
            return result

        tracker.extractor.grab_minimap = grab
        tracker._detector.detect = detect
        engine_module.score_and_assign = score

    def run(self):
        frame_count = 0
        fps_started = time.perf_counter()
        while not self.stop.is_set():
            loop_started = time.perf_counter()
            try:
                state = fetch_json(self.backend_url + "/api/state")
                calibration = fetch_json(self.backend_url + "/api/calibration")
                if state.get("_game_ended") or not self.rebuild(state, calibration):
                    self._set_waiting("game/calibration/targets unavailable")
                    time.sleep(0.5)
                    continue
                started = time.perf_counter_ns()
                payload = self.engine.run_frame()
                total_ms = (time.perf_counter_ns() - started) / 1e6
                if payload is None:
                    self._set_waiting("capture returned no frame")
                    continue
                frame_count += 1
                elapsed = time.perf_counter() - fps_started
                fps = frame_count / elapsed if elapsed > 0 else 0
                if elapsed >= 5:
                    frame_count = 0
                    fps_started = time.perf_counter()
                self.samples.append(total_ms)
                self.samples = self.samples[-120:]
                sorted_samples = sorted(self.samples)
                p95 = sorted_samples[round((len(sorted_samples) - 1) * 0.95)]
                average = sum(self.samples) / len(self.samples)
                annotated = payload.frame.copy()
                detections = []
                for detection in payload.detections:
                    x1, y1, x2, y2 = detection.box
                    color = (0, 255, 0) if detection.kind == "IDENTIFIED" else (0, 165, 255)
                    cv2.rectangle(annotated, (x1, y1), (x2, y2), color, 2)
                    detections.append({
                        "box": list(detection.box),
                        "kind": detection.kind,
                        "name": detection.name,
                        "confidence": detection.conf,
                        "template_score": detection.tm_score,
                        "histogram_score": detection.hist_score,
                    })
                images = {
                    "frame": cv2.imencode(".png", payload.frame)[1].tobytes(),
                    "mask": cv2.imencode(".png", payload.mask)[1].tobytes(),
                    "annotated": cv2.imencode(".png", annotated)[1].tobytes(),
                }
                metrics = dict(self.timings)
                cpu_now = time.process_time()
                wall_now = time.perf_counter()
                cpu_delta = cpu_now - self.last_cpu_time
                wall_delta = wall_now - self.last_wall_time
                self.last_cpu_time = cpu_now
                self.last_wall_time = wall_now
                metrics.update({
                    "total_ms": total_ms,
                    "average_ms": average,
                    "p95_ms": p95,
                    "fps": fps,
                    "target_fps": self.engine.target_fps,
                    "cpu_percent": (cpu_delta / wall_delta * 100) if wall_delta > 0 else 0,
                    "working_set_bytes": working_set_bytes(),
                    "duty_percent": total_ms * self.engine.target_fps / 10,
                })
                snapshot = {
                    "status": "running",
                    "timestamp": time.time(),
                    "metrics": metrics,
                    "detections": detections,
                    "targets": [target.name for target in payload.targets_ref],
                    "state": {
                        name: {
                            "confidence": value.conf,
                            "location": list(value.loc) if value.loc else None,
                            "last_seen": value.last_seen,
                        }
                        for name, value in payload.state.items()
                    },
                    "shape": list(payload.raw_shape),
                    "calibration": calibration,
                }
                with self.lock:
                    self.snapshot = snapshot
                    self.images = images
                if self.record_dir and frame_count % self.record_every == 0:
                    self._record_frame(payload, snapshot, images)
            except Exception as error:
                self._set_waiting(str(error))
            delay = max(0, (1 / 6) - (time.perf_counter() - loop_started))
            self.stop.wait(delay)

    def _record_frame(self, payload, snapshot, images):
        index = self.record_index
        self.record_index += 1
        stem = f"frame-{index:06d}"
        (self.record_dir / f"{stem}.png").write_bytes(images["frame"])
        (self.record_dir / f"{stem}.bgr").write_bytes(payload.frame.tobytes())
        expected = {
            "timestamp": snapshot["timestamp"],
            "shape": snapshot["shape"],
            "targets": snapshot["targets"],
            "detections": snapshot["detections"],
            "state": snapshot["state"],
            "icon_size": self.engine.extractor.icon_size,
            "target_icons": {},
        }
        target_dir = self.record_dir / "targets"
        target_dir.mkdir(exist_ok=True)
        for name, source in self.target_icon_paths.items():
            destination = target_dir / Path(source).name
            if not destination.exists():
                shutil.copy2(source, destination)
            expected["target_icons"][name] = str(destination.relative_to(self.record_dir))
        (self.record_dir / f"{stem}.json").write_text(
            json.dumps(expected, ensure_ascii=False),
            encoding="utf-8",
        )

    def _set_waiting(self, reason):
        with self.lock:
            self.snapshot = {"status": "waiting", "reason": reason, "metrics": {}, "detections": []}


class Handler(BaseHTTPRequestHandler):
    diagnostics = None

    def do_GET(self):
        if self.path in ("/", "/health", "/api/diagnostics"):
            with self.diagnostics.lock:
                body = json.dumps(self.diagnostics.snapshot).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        image_name = {"/frame.png": "frame", "/mask.png": "mask", "/annotated.png": "annotated"}.get(self.path)
        if image_name:
            with self.diagnostics.lock:
                body = self.diagnostics.images.get(image_name)
            if body is None:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_error(404)

    def log_message(self, format, *args):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", default="http://127.0.0.1:8420")
    parser.add_argument("--port", type=int, default=8430)
    parser.add_argument("--data-dir", default=os.path.join(os.environ.get("APPDATA", "."), "GodSense", "python-diagnostics"))
    parser.add_argument("--record-dir")
    parser.add_argument("--record-every", type=int, default=6)
    args = parser.parse_args()
    diagnostics = Diagnostics(
        args.backend,
        args.data_dir,
        record_dir=args.record_dir,
        record_every=args.record_every,
    )
    Handler.diagnostics = diagnostics
    worker = threading.Thread(target=diagnostics.run, daemon=True)
    worker.start()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Python CV diagnostics: http://127.0.0.1:{args.port}/api/diagnostics", flush=True)
    try:
        server.serve_forever()
    finally:
        diagnostics.stop.set()
        server.server_close()


if __name__ == "__main__":
    main()
