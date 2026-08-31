import json
import os
from pathlib import Path

from coach_core.gank import GankDetector
from coach_core.models import ChampionPosition
from coach_core.sighting import JunglerSightingTracker


ROOT = Path(os.environ.get("APPDATA", ".")) / "GodSense" / "alert-corpus.json"
WIDTH = 300
HEIGHT = 300
ROLES = {"EnemyJungle": "JUNGLE", "EnemyMid": "MIDDLE"}


def position(name, x_frac, y_frac, timestamp):
    return ChampionPosition(
        champion_name=name,
        x=round(x_frac * WIDTH),
        y=round(y_frac * HEIGHT),
        confidence=0.9,
        timestamp=timestamp,
    )


def main():
    sequence = [
        (0.0, {}),
        (1.0, {"EnemyJungle": position("EnemyJungle", .246, .258, 1.0)}),
        (1.1, {"EnemyJungle": position("EnemyJungle", .246, .258, 1.1)}),
        (2.0, {"EnemyJungle": position("EnemyJungle", .312, .358, 2.0)}),
        (2.5, {"EnemyJungle": position("EnemyJungle", .784, .727, 2.5)}),
        (4.2, {"EnemyJungle": position("EnemyJungle", .784, .727, 4.2)}),
        (5.0, {}),
        (10.0, {}),
        (22.6, {}),
        (22.7, {"EnemyJungle": position("EnemyJungle", .784, .727, 22.7)}),
        (23.0, {"EnemyMid": position("EnemyMid", .539, .373, 23.0)}),
        (23.1, {"EnemyMid": position("EnemyMid", .539, .373, 23.1)}),
        (24.0, {}),
        (24.1, {"EnemyMid": position("EnemyMid", .539, .373, 24.1)}),
    ]
    gank = GankDetector()
    sighting = JunglerSightingTracker()
    frames = []
    for timestamp, positions in sequence:
        ganks = gank.check(
            positions,
            "MIDDLE",
            "ORDER",
            ROLES,
            WIDTH,
            HEIGHT,
        )
        sightings = sighting.check(
            positions,
            ROLES,
            WIDTH,
            HEIGHT,
            timestamp,
        )
        frames.append(
            {
                "timestamp": timestamp,
                "positions": {
                    name: {
                        "x": value.x,
                        "y": value.y,
                        "confidence": value.confidence,
                        "timestamp": value.timestamp,
                    }
                    for name, value in positions.items()
                },
                "ganks": [item.to_dict() for item in ganks],
                "sightings": [item.to_dict() for item in sightings],
            }
        )
    ROOT.write_text(
        json.dumps(
            {
                "width": WIDTH,
                "height": HEIGHT,
                "coached_role": "MIDDLE",
                "enemy_roles": ROLES,
                "frames": frames,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"Alert corpus generated: {ROOT}")


if __name__ == "__main__":
    main()
