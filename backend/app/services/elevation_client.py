from typing import Dict, List, Mapping, Sequence, Set, Tuple

import httpx

from app.services.geo import interpolate_latlon_at_distance
from app.services.speed_bump_repository import MatchedBump
from app.services.tmap_client import TmapRoute


CoordinateKey = Tuple[float, float]


class ElevationClient:
    def __init__(
        self,
        api_url: str,
        *,
        enabled: bool,
        sample_offset_m: float = 20.0,
        timeout_s: float = 6.0,
    ) -> None:
        self.api_url = api_url
        self.enabled = enabled
        self.sample_offset_m = sample_offset_m
        self.timeout_s = timeout_s
        self._cache: Dict[CoordinateKey, float] = {}

    async def classify_uphill_bumps(
        self,
        routes: Sequence[TmapRoute],
        matches_by_route_id: Mapping[str, Sequence[MatchedBump]],
    ) -> Dict[str, Set[int]]:
        if not self.enabled:
            return {}

        sample_pairs: Dict[Tuple[str, int], Tuple[CoordinateKey, CoordinateKey]] = {}
        coordinates: Dict[CoordinateKey, Tuple[float, float]] = {}

        for route in routes:
            for match in matches_by_route_id.get(route.id, []):
                bump = match.bump
                if (
                    bump.density_count > 1
                    or not bump.slope_degree
                    or bump.impact_score <= 0
                ):
                    continue

                before = interpolate_latlon_at_distance(
                    route.polyline,
                    match.distance_along_route_m - self.sample_offset_m,
                )
                after = interpolate_latlon_at_distance(
                    route.polyline,
                    match.distance_along_route_m + self.sample_offset_m,
                )
                before_key = _coordinate_key(before)
                after_key = _coordinate_key(after)
                if before_key == after_key:
                    continue

                sample_pairs[(route.id, bump.id)] = (before_key, after_key)
                coordinates[before_key] = before
                coordinates[after_key] = after

        if not sample_pairs:
            return {}

        elevations = await self._lookup_elevations(coordinates)
        uphill_by_route_id: Dict[str, Set[int]] = {}
        for (route_id, bump_id), (before_key, after_key) in sample_pairs.items():
            before_elevation = elevations.get(before_key)
            after_elevation = elevations.get(after_key)
            if before_elevation is None or after_elevation is None:
                continue
            if after_elevation > before_elevation:
                uphill_by_route_id.setdefault(route_id, set()).add(bump_id)

        return uphill_by_route_id

    async def _lookup_elevations(
        self, coordinates: Mapping[CoordinateKey, Tuple[float, float]]
    ) -> Dict[CoordinateKey, float]:
        missing = [key for key in coordinates if key not in self._cache]
        if missing:
            payload = {
                "locations": [
                    {
                        "latitude": coordinates[key][0],
                        "longitude": coordinates[key][1],
                    }
                    for key in missing
                ]
            }
            async with httpx.AsyncClient(timeout=self.timeout_s) as client:
                response = await client.post(
                    self.api_url,
                    json=payload,
                    headers={"Accept": "application/json"},
                )
            response.raise_for_status()
            results: List[dict] = response.json().get("results") or []
            for key, result in zip(missing, results):
                elevation = result.get("elevation")
                if elevation is not None:
                    self._cache[key] = float(elevation)

        return {
            key: self._cache[key]
            for key in coordinates
            if key in self._cache
        }


def _coordinate_key(coordinate: Tuple[float, float]) -> CoordinateKey:
    return round(coordinate[0], 6), round(coordinate[1], 6)
