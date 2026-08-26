from dataclasses import dataclass, replace
from typing import List, Sequence, Tuple

from app.services.geo import cumulative_lengths, point_to_polyline_distance, project_points
from app.services.tmap_client import TmapRoute


ROUTE_SAMPLE_INTERVAL_M = 100.0
ROUTE_SIMILARITY_DISTANCE_M = 15.0
ROUTE_SIMILARITY_OVERLAP_RATIO = 0.95
ROUTE_SIMILARITY_DISTANCE_RATIO = 0.02


@dataclass(frozen=True)
class RouteDeduplicationResult:
    routes: List[TmapRoute]
    merged_count: int


def deduplicate_routes(routes: Sequence[TmapRoute]) -> RouteDeduplicationResult:
    unique: List[TmapRoute] = []
    merged_count = 0

    for route in sorted(routes, key=lambda item: item.summary.total_time_s):
        duplicate_index = next(
            (
                idx
                for idx, existing in enumerate(unique)
                if routes_are_similar(existing, route)
            ),
            None,
        )
        if duplicate_index is None:
            unique.append(
                replace(route, source_search_options=tuple(sorted(route.search_options)))
            )
            continue

        existing = unique[duplicate_index]
        merged_options = tuple(
            sorted(set(existing.search_options).union(route.search_options))
        )
        unique[duplicate_index] = replace(
            existing,
            source_search_options=merged_options,
        )
        merged_count += 1

    return RouteDeduplicationResult(routes=unique, merged_count=merged_count)


def routes_are_similar(first: TmapRoute, second: TmapRoute) -> bool:
    if not first.polyline or not second.polyline:
        return False

    longer_distance = max(
        first.summary.total_distance_m,
        second.summary.total_distance_m,
        1.0,
    )
    distance_ratio = abs(
        first.summary.total_distance_m - second.summary.total_distance_m
    ) / longer_distance
    if distance_ratio > ROUTE_SIMILARITY_DISTANCE_RATIO:
        return False

    origin = first.polyline[0]
    first_xy = project_points(first.polyline, origin)
    second_xy = project_points(second.polyline, origin)
    first_cumulative = cumulative_lengths(first_xy)
    second_cumulative = cumulative_lengths(second_xy)

    if not _endpoints_are_close(first_xy, second_xy):
        return False

    return (
        _directed_overlap(first_xy, first_cumulative, second_xy, second_cumulative)
        >= ROUTE_SIMILARITY_OVERLAP_RATIO
        and _directed_overlap(second_xy, second_cumulative, first_xy, first_cumulative)
        >= ROUTE_SIMILARITY_OVERLAP_RATIO
    )


def _endpoints_are_close(
    first_xy: Sequence[Tuple[float, float]],
    second_xy: Sequence[Tuple[float, float]],
) -> bool:
    for first, second in ((first_xy[0], second_xy[0]), (first_xy[-1], second_xy[-1])):
        distance, _ = point_to_polyline_distance(first, [second], [0.0])
        if distance > ROUTE_SIMILARITY_DISTANCE_M:
            return False
    return True


def _directed_overlap(
    source_xy: Sequence[Tuple[float, float]],
    source_cumulative: Sequence[float],
    target_xy: Sequence[Tuple[float, float]],
    target_cumulative: Sequence[float],
) -> float:
    samples = _sample_polyline(source_xy, source_cumulative)
    within_threshold = sum(
        point_to_polyline_distance(sample, target_xy, target_cumulative)[0]
        <= ROUTE_SIMILARITY_DISTANCE_M
        for sample in samples
    )
    return within_threshold / max(1, len(samples))


def _sample_polyline(
    points_xy: Sequence[Tuple[float, float]],
    cumulative_m: Sequence[float],
) -> List[Tuple[float, float]]:
    if len(points_xy) <= 1:
        return list(points_xy)

    total_m = cumulative_m[-1]
    targets = [0.0]
    target = ROUTE_SAMPLE_INTERVAL_M
    while target < total_m:
        targets.append(target)
        target += ROUTE_SAMPLE_INTERVAL_M
    targets.append(total_m)

    samples: List[Tuple[float, float]] = []
    segment_idx = 1
    for target_m in targets:
        while segment_idx < len(cumulative_m) - 1 and cumulative_m[segment_idx] < target_m:
            segment_idx += 1
        start_m = cumulative_m[segment_idx - 1]
        end_m = cumulative_m[segment_idx]
        segment_m = end_m - start_m
        ratio = 0.0 if segment_m == 0 else (target_m - start_m) / segment_m
        ax, ay = points_xy[segment_idx - 1]
        bx, by = points_xy[segment_idx]
        samples.append((ax + (bx - ax) * ratio, ay + (by - ay) * ratio))
    return samples
