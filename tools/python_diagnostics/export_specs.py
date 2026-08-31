import json

from coach_core.gank import GankConfig
from coach_core.map import LOCATIONS
from coach_core.sighting import SightingConfig


print(
    json.dumps(
        {
            "locations": [
                {
                    "name": item.name,
                    "x": item.x_frac,
                    "y": item.y_frac,
                    "side": item.side,
                    "region": item.region,
                }
                for item in LOCATIONS
            ],
            "gank_zones": {
                role: GankConfig().get_zones(role)
                for role in ("TOP", "MIDDLE", "BOTTOM", "UTILITY", "JUNGLE")
            },
            "sighting": {
                "rearm_unseen_s": SightingConfig().rearm_unseen_s,
                "min_refire_interval_s": SightingConfig().min_refire_interval_s,
            },
        },
        ensure_ascii=False,
    )
)
