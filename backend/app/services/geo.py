import math
from typing import Iterable, List, Optional, Sequence, Tuple


EARTH_RADIUS_M = 6371008.8
LatLon = Tuple[float, float]
XY = Tuple[float, float]


def meters_to_degrees_lat(meters: float) -> float:
    return meters / 111_320.0


def meters_to_degrees_lon(meters: float, lat: float) -> float:
    cos_lat = max(0.15, math.cos(math.radians(lat)))
    return meters / (111_320.0 * cos_lat)


def haversine_m(a: LatLon, b: LatLon) -> float:
    lat1, lon1 = map(math.radians, a)
    lat2, lon2 = map(math.radians, b)
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    sin_dlat = math.sin(dlat / 2)
    sin_dlon = math.sin(dlon / 2)
    h = sin_dlat * sin_dlat + math.cos(lat1) * math.cos(lat2) * sin_dlon * sin_dlon
    return 2 * EARTH_RADIUS_M * math.asin(min(1.0, math.sqrt(h)))


def project_points(points: Sequence[LatLon], origin: LatLon) -> List[XY]:
    origin_lat, origin_lon = origin
    origin_lat_rad = math.radians(origin_lat)
    projected: List[XY] = []
    for lat, lon in points:
        x = math.radians(lon - origin_lon) * EARTH_RADIUS_M * math.cos(origin_lat_rad)
        y = math.radians(lat - origin_lat) * EARTH_RADIUS_M
        projected.append((x, y))
    return projected


def cumulative_lengths(points_xy: Sequence[XY]) -> List[float]:
    totals = [0.0]
    for idx in range(1, len(points_xy)):
        ax, ay = points_xy[idx - 1]
        bx, by = points_xy[idx]
        totals.append(totals[-1] + math.hypot(bx - ax, by - ay))
    return totals


def point_to_polyline_distance(
    point_xy: XY,
    polyline_xy: Sequence[XY],
    cumulative_m: Sequence[float],
    segment_indices: Optional[Iterable[int]] = None,
) -> Tuple[float, float]:
    if len(polyline_xy) == 1:
        px, py = point_xy
        ax, ay = polyline_xy[0]
        return math.hypot(px - ax, py - ay), 0.0

    px, py = point_xy
    best_distance = float("inf")
    best_along = 0.0

    indices = segment_indices if segment_indices is not None else range(1, len(polyline_xy))
    for idx in indices:
        if idx <= 0 or idx >= len(polyline_xy):
            continue
        ax, ay = polyline_xy[idx - 1]
        bx, by = polyline_xy[idx]
        vx = bx - ax
        vy = by - ay
        seg_len_sq = vx * vx + vy * vy
        if seg_len_sq == 0:
            t = 0.0
        else:
            t = ((px - ax) * vx + (py - ay) * vy) / seg_len_sq
            t = max(0.0, min(1.0, t))

        nearest_x = ax + t * vx
        nearest_y = ay + t * vy
        distance = math.hypot(px - nearest_x, py - nearest_y)
        if distance < best_distance:
            best_distance = distance
            segment_len = math.sqrt(seg_len_sq)
            best_along = cumulative_m[idx - 1] + t * segment_len

    return best_distance, best_along


def interpolate_latlon_at_distance(
    polyline: Sequence[LatLon], distance_m: float
) -> LatLon:
    if not polyline:
        raise ValueError("Polyline must include at least one coordinate.")
    if len(polyline) == 1:
        return polyline[0]

    projected = project_points(polyline, polyline[0])
    cumulative_m = cumulative_lengths(projected)
    target_m = max(0.0, min(distance_m, cumulative_m[-1]))

    for idx in range(1, len(polyline)):
        segment_end_m = cumulative_m[idx]
        if target_m > segment_end_m:
            continue

        segment_start_m = cumulative_m[idx - 1]
        segment_length_m = segment_end_m - segment_start_m
        ratio = (
            0.0
            if segment_length_m == 0
            else (target_m - segment_start_m) / segment_length_m
        )
        start_lat, start_lon = polyline[idx - 1]
        end_lat, end_lon = polyline[idx]
        return (
            start_lat + (end_lat - start_lat) * ratio,
            start_lon + (end_lon - start_lon) * ratio,
        )

    return polyline[-1]


def bounds(points: Iterable[LatLon]) -> Tuple[float, float, float, float]:
    lats = []
    lons = []
    for lat, lon in points:
        lats.append(lat)
        lons.append(lon)
    return min(lats), min(lons), max(lats), max(lons)
