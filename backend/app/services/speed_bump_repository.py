from dataclasses import dataclass
import csv
import math
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

from app.services.geo import (
    bounds,
    cumulative_lengths,
    meters_to_degrees_lat,
    meters_to_degrees_lon,
    point_to_polyline_distance,
    project_points,
)


GridKey = Tuple[int, int]
LatLon = Tuple[float, float]


@dataclass(frozen=True)
class SpeedBump:
    id: int
    province: str
    district: str
    road_name: str
    address: str
    bump_type: str
    height_cm: Optional[float]
    width_cm: Optional[float]
    lat: float
    lon: float
    continuous_yn: str
    separated_sidewalk_yn: str
    density_count: int
    slope_degree: Optional[float]
    impact_score: float
    meter_penalty: float

    @property
    def is_virtual(self) -> bool:
        return "가상" in self.bump_type


@dataclass(frozen=True)
class MatchedBump:
    bump: SpeedBump
    distance_from_route_m: float
    distance_along_route_m: float


class SpeedBumpRepository:
    def __init__(self, csv_path: Path, cell_size_deg: float = 0.01) -> None:
        self.csv_path = csv_path
        self.cell_size_deg = cell_size_deg
        self.bumps: List[SpeedBump] = []
        self._grid: Dict[GridKey, List[SpeedBump]] = {}

    def load(self) -> None:
        if not self.csv_path.exists():
            raise FileNotFoundError(f"Speed bump CSV not found: {self.csv_path}")

        loaded: List[SpeedBump] = []
        with self.csv_path.open("r", encoding="utf-8-sig", newline="") as csv_file:
            reader = csv.DictReader(csv_file)
            for idx, row in enumerate(reader, start=1):
                try:
                    lat = float(row["위도"])
                    lon = float(row["경도"])
                except (KeyError, TypeError, ValueError):
                    continue
                if not (33.0 <= lat <= 39.5 and 124.0 <= lon <= 132.5):
                    continue

                loaded.append(
                    SpeedBump(
                        id=idx,
                        province=row.get("시도", "").strip(),
                        district=row.get("시군구", "").strip(),
                        road_name=row.get("도로명", "").strip(),
                        address=row.get("주소", "").strip(),
                        bump_type=row.get("유형", "").strip(),
                        height_cm=_to_optional_float(row.get("높이_cm")),
                        width_cm=_to_optional_float(row.get("폭_cm")),
                        lat=lat,
                        lon=lon,
                        continuous_yn=(row.get("연속형여부", "") or "N").strip() or "N",
                        separated_sidewalk_yn=(row.get("보차분리여부", "") or "N").strip()
                        or "N",
                        density_count=_to_int(row.get("밀집개수"), default=1),
                        slope_degree=_to_optional_float(row.get("경사도_도")),
                        impact_score=_to_float(row.get("충격점수"), default=0.0),
                        meter_penalty=_to_float(row.get("미터당감점"), default=0.0),
                    )
                )

        self.bumps = loaded
        self._build_grid()

    def _build_grid(self) -> None:
        grid: Dict[GridKey, List[SpeedBump]] = {}
        for bump in self.bumps:
            key = self._grid_key(bump.lat, bump.lon)
            grid.setdefault(key, []).append(bump)
        self._grid = grid

    def _grid_key(self, lat: float, lon: float) -> GridKey:
        return (
            math.floor(lat / self.cell_size_deg),
            math.floor(lon / self.cell_size_deg),
        )

    def nearby(self, lat: float, lon: float, radius_m: float) -> List[MatchedBump]:
        pseudo_route = [(lat, lon)]
        candidates = self._candidates_for_bounds(
            lat - meters_to_degrees_lat(radius_m),
            lon - meters_to_degrees_lon(radius_m, lat),
            lat + meters_to_degrees_lat(radius_m),
            lon + meters_to_degrees_lon(radius_m, lat),
        )
        origin = (lat, lon)
        point_xy = project_points([origin], origin)[0]
        matched: List[MatchedBump] = []
        for bump in candidates:
            bump_xy = project_points([(bump.lat, bump.lon)], origin)[0]
            distance = math.hypot(bump_xy[0] - point_xy[0], bump_xy[1] - point_xy[1])
            if distance <= radius_m:
                matched.append(MatchedBump(bump, distance, 0.0))
        matched.sort(key=lambda item: item.distance_from_route_m)
        return matched

    def match_route(
        self,
        polyline: Sequence[LatLon],
        buffer_m: float,
        exclude_virtual: bool,
        excluded_polylines: Sequence[Sequence[LatLon]] = (),
    ) -> List[MatchedBump]:
        if not polyline:
            return []

        min_lat, min_lon, max_lat, max_lon = bounds(polyline)
        mid_lat = (min_lat + max_lat) / 2
        lat_pad = meters_to_degrees_lat(buffer_m)
        lon_pad = meters_to_degrees_lon(buffer_m, mid_lat)
        candidates = self._candidates_for_bounds(
            min_lat - lat_pad,
            min_lon - lon_pad,
            max_lat + lat_pad,
            max_lon + lon_pad,
        )

        origin = polyline[0]
        polyline_xy = project_points(polyline, origin)
        cumulative_m = cumulative_lengths(polyline_xy)
        excluded_xy = []
        for excluded_polyline in excluded_polylines:
            if not excluded_polyline:
                continue
            projected = project_points(excluded_polyline, origin)
            excluded_xy.append((projected, cumulative_lengths(projected)))

        matched: List[MatchedBump] = []
        for bump in candidates:
            if exclude_virtual and bump.is_virtual:
                continue
            bump_xy = project_points([(bump.lat, bump.lon)], origin)[0]
            distance_m, along_m = point_to_polyline_distance(
                bump_xy, polyline_xy, cumulative_m
            )
            if distance_m <= buffer_m:
                if _nearest_route_geometry_is_excluded(
                    bump_xy,
                    distance_m,
                    excluded_xy,
                ):
                    continue
                matched.append(MatchedBump(bump, distance_m, along_m))

        matched.sort(key=lambda item: item.distance_along_route_m)
        return matched

    def _candidates_for_bounds(
        self, min_lat: float, min_lon: float, max_lat: float, max_lon: float
    ) -> List[SpeedBump]:
        min_key = self._grid_key(min_lat, min_lon)
        max_key = self._grid_key(max_lat, max_lon)
        seen: Set[int] = set()
        candidates: List[SpeedBump] = []

        for lat_key in range(min_key[0], max_key[0] + 1):
            for lon_key in range(min_key[1], max_key[1] + 1):
                for bump in self._grid.get((lat_key, lon_key), []):
                    if bump.id in seen:
                        continue
                    seen.add(bump.id)
                    candidates.append(bump)

        return candidates


def _nearest_route_geometry_is_excluded(
    point_xy: Tuple[float, float],
    route_distance_m: float,
    excluded_xy: Sequence[Tuple[Sequence[Tuple[float, float]], Sequence[float]]],
) -> bool:
    for polyline_xy, cumulative_m in excluded_xy:
        distance_m, _ = point_to_polyline_distance(
            point_xy,
            polyline_xy,
            cumulative_m,
        )
        if distance_m <= route_distance_m + 0.5:
            return True
    return False


def _to_optional_float(value: object) -> Optional[float]:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _to_float(value: object, default: float) -> float:
    parsed = _to_optional_float(value)
    return default if parsed is None else parsed


def _to_int(value: object, default: int) -> int:
    if value is None or value == "":
        return default
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default
