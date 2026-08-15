import asyncio
import json
import os
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings  # noqa: E402
from app.models.schemas import Coordinate  # noqa: E402
from app.services.speed_bump_repository import SpeedBumpRepository  # noqa: E402
from app.services.tmap_client import TmapClient  # noqa: E402


async def main() -> None:
    settings = get_settings()
    repository = SpeedBumpRepository(settings.speed_bump_csv_path)
    repository.load()
    print(f"loaded_bumps={len(repository.bumps)}")

    client = TmapClient(settings.tmap_app_key, settings.tmap_route_api_url)
    route = await client.get_car_route(
        Coordinate(lat=37.566295, lon=126.977945, name="서울시청"),
        Coordinate(lat=37.570377, lon=126.992153, name="종로3가"),
        search_option=0,
    )
    matches = repository.match_route(
        route.polyline,
        buffer_m=30,
        exclude_virtual=True,
        excluded_polylines=route.speed_bump_excluded_polylines,
    )
    result = {
        "route_id": route.id,
        "distance_m": route.summary.total_distance_m,
        "time_s": route.summary.total_time_s,
        "polyline_points": len(route.polyline),
        "matched_bumps": len(matches),
        "first_matches": [
            {
                "id": item.bump.id,
                "road_name": item.bump.road_name,
                "impact_score": item.bump.impact_score,
                "along_m": round(item.distance_along_route_m, 1),
                "off_route_m": round(item.distance_from_route_m, 1),
            }
            for item in matches[:5]
        ],
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
