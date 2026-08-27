from dataclasses import dataclass
import math
from typing import Dict, List, Optional, Sequence, Set

from app.models.schemas import (
    BumpMatch,
    CandidateRoute,
    Coordinate,
    RouteWarning,
)
from app.services.speed_bump_repository import MatchedBump, SpeedBump
from app.services.tmap_client import TmapRoute


DENSE_GROUP_MAX_GAP_M = 120.0
DENSE_SEGMENT_EDGE_MARGIN_M = 8.0
SLOPE_WTR_RATIO = 0.55 / 1.35


@dataclass(frozen=True)
class RoutePenalty:
    independent: float
    dense: float

    @property
    def total(self) -> float:
        return self.independent + self.dense


@dataclass(frozen=True)
class RouteEligibility:
    routes: List[TmapRoute]
    fastest_time_s: float
    shortest_distance_m: float


def select_eligible_routes(
    routes: Sequence[TmapRoute],
    *,
    max_time_over_fastest_ratio: float,
    max_distance_over_shortest_ratio: Optional[float],
) -> RouteEligibility:
    if not routes:
        return RouteEligibility([], 0.0, 0.0)

    fastest_route = min(routes, key=lambda route: route.summary.total_time_s)
    fastest_time = fastest_route.summary.total_time_s
    shortest_distance = min(route.summary.total_distance_m for route in routes)
    max_time = fastest_time * (1 + max_time_over_fastest_ratio)
    max_distance = (
        shortest_distance * (1 + max_distance_over_shortest_ratio)
        if max_distance_over_shortest_ratio is not None
        else None
    )
    eligible_routes = [
        route
        for route in routes
        if route.summary.total_time_s <= max_time
        and (
            max_distance is None
            or route.summary.total_distance_m <= max_distance
        )
    ]
    if fastest_route not in eligible_routes:
        eligible_routes.append(fastest_route)

    return RouteEligibility(
        routes=eligible_routes,
        fastest_time_s=fastest_time,
        shortest_distance_m=shortest_distance,
    )


def build_candidate_routes(
    routes: Sequence[TmapRoute],
    matches_by_route_id: Dict[str, List[MatchedBump]],
    alert_distances_m: List[int],
    min_alert_impact_score: float,
    max_time_over_fastest_ratio: float,
    max_distance_over_shortest_ratio: Optional[float],
    uphill_bump_ids_by_route_id: Optional[Dict[str, Set[int]]] = None,
    routes_are_eligible: bool = False,
    baseline_fastest_time_s: Optional[float] = None,
    baseline_shortest_distance_m: Optional[float] = None,
) -> List[CandidateRoute]:
    if not routes:
        return []

    if routes_are_eligible:
        eligible_routes = list(routes)
        fastest_time = baseline_fastest_time_s or min(
            route.summary.total_time_s for route in routes
        )
        shortest_distance = baseline_shortest_distance_m or min(
            route.summary.total_distance_m for route in routes
        )
    else:
        eligibility = select_eligible_routes(
            routes,
            max_time_over_fastest_ratio=max_time_over_fastest_ratio,
            max_distance_over_shortest_ratio=max_distance_over_shortest_ratio,
        )
        eligible_routes = eligibility.routes
        fastest_time = eligibility.fastest_time_s
        shortest_distance = eligibility.shortest_distance_m

    candidates: List[CandidateRoute] = []
    uphill_bump_ids_by_route_id = uphill_bump_ids_by_route_id or {}

    for route in eligible_routes:
        matches = matches_by_route_id.get(route.id, [])
        uphill_bump_ids = uphill_bump_ids_by_route_id.get(route.id, set())
        alert_matches = [
            item
            for item in matches
            if (
                item.bump.density_count > 1
                and item.bump.meter_penalty > 0
            )
            or _independent_impact_score(
                item.bump, item.bump.id in uphill_bump_ids
            )
            >= min_alert_impact_score
        ]
        warnings = build_warnings(alert_matches, alert_distances_m)
        penalty = calculate_route_penalty(matches, uphill_bump_ids)
        impact_sum = penalty.total
        continuous_warning_count = sum(1 for warning in warnings if warning.kind == "continuous")
        added_time_s = max(0.0, route.summary.total_time_s - fastest_time)
        added_distance_m = max(0.0, route.summary.total_distance_m - shortest_distance)
        comfort_score = max(0.0, 100.0 - impact_sum)
        expressway_distance_m = min(
            route.summary.total_distance_m,
            route.expressway_distance_m,
        )
        scorable_distance_m = max(
            0.0,
            route.summary.total_distance_m - expressway_distance_m,
        )
        normalization_distance_km = max(1.0, scorable_distance_m / 1000.0)
        impact_per_10km = impact_sum * 10.0 / normalization_distance_km
        distance_normalized_score = max(0.0, 100.0 - impact_per_10km)

        candidates.append(
            CandidateRoute(
                id=route.id,
                search_option=route.search_option,
                search_options=list(route.search_options),
                search_option_label=route.label,
                rank=0,
                score=round(distance_normalized_score, 3),
                raw_score=round(comfort_score, 3),
                distance_normalized_score=round(distance_normalized_score, 3),
                impact_per_10km=round(impact_per_10km, 3),
                summary=route.summary,
                added_time_s=round(added_time_s, 1),
                added_distance_m=round(added_distance_m, 1),
                bump_count=len(matches),
                impact_sum=round(impact_sum, 3),
                continuous_warning_count=continuous_warning_count,
                is_expressway=expressway_distance_m > 0,
                contains_expressway=expressway_distance_m > 0,
                expressway_distance_m=round(expressway_distance_m, 1),
                tunnel_distance_m=round(route.tunnel_distance_m, 1),
                scorable_distance_m=round(scorable_distance_m, 1),
                road_types=route.road_types,
                facility_types=route.facility_types,
                warnings=warnings,
                matched_bumps=[to_bump_match(item) for item in matches],
                polyline=[
                    Coordinate(lat=lat, lon=lon) for lat, lon in route.polyline
                ],
            )
        )

    candidates.sort(
        key=lambda candidate: (
            -candidate.score,
            candidate.impact_sum,
            candidate.bump_count,
            candidate.summary.total_time_s,
        )
    )
    for idx, candidate in enumerate(candidates, start=1):
        candidate.rank = idx
    return candidates


def calculate_route_penalty(
    matches: Sequence[MatchedBump], uphill_bump_ids: Set[int]
) -> RoutePenalty:
    independent_penalty = sum(
        _independent_impact_score(
            match.bump, match.bump.id in uphill_bump_ids
        )
        for match in matches
        if match.bump.density_count <= 1
    )
    dense_penalty = sum(
        _dense_group_penalty(group) for group in _dense_groups(matches)
    )
    return RoutePenalty(
        independent=independent_penalty,
        dense=dense_penalty,
    )


def build_warnings(
    matches: Sequence[MatchedBump], alert_distances_m: List[int]
) -> List[RouteWarning]:
    warnings: List[RouteWarning] = []
    current_group: List[MatchedBump] = []

    for match in matches:
        if _is_continuous(match.bump):
            if (
                current_group
                and match.distance_along_route_m - current_group[-1].distance_along_route_m <= 120
            ):
                current_group.append(match)
            else:
                if current_group:
                    warnings.append(_continuous_warning(current_group, alert_distances_m))
                current_group = [match]
        else:
            if current_group:
                warnings.append(_continuous_warning(current_group, alert_distances_m))
                current_group = []
            warnings.append(_single_warning(match, alert_distances_m))

    if current_group:
        warnings.append(_continuous_warning(current_group, alert_distances_m))

    warnings.sort(key=lambda item: item.distance_along_route_m)
    return warnings


def to_bump_match(item: MatchedBump) -> BumpMatch:
    bump = item.bump
    return BumpMatch(
        id=bump.id,
        lat=bump.lat,
        lon=bump.lon,
        road_name=bump.road_name,
        address=bump.address,
        bump_type=bump.bump_type,
        height_cm=bump.height_cm,
        width_cm=bump.width_cm,
        impact_score=round(bump.impact_score, 3),
        continuous_yn=bump.continuous_yn,
        density_count=bump.density_count,
        meter_penalty=round(bump.meter_penalty, 5),
        penalty_kind="dense" if bump.density_count > 1 else "independent",
        distance_from_route_m=round(item.distance_from_route_m, 2),
        distance_along_route_m=round(item.distance_along_route_m, 1),
    )


def _single_warning(match: MatchedBump, alert_distances_m: List[int]) -> RouteWarning:
    bump = match.bump
    return RouteWarning(
        kind="single",
        message=f"{int(match.distance_along_route_m)}m 지점 방지턱",
        trigger_distances_m=alert_distances_m,
        distance_along_route_m=round(match.distance_along_route_m, 1),
        lat=bump.lat,
        lon=bump.lon,
        bump_count=1,
        impact_sum=round(bump.impact_score, 3),
        bump_ids=[bump.id],
    )


def _continuous_warning(
    group: Sequence[MatchedBump], alert_distances_m: List[int]
) -> RouteWarning:
    first = group[0]
    impact_sum = (
        _dense_group_penalty(group)
        if any(item.bump.density_count > 1 for item in group)
        else sum(item.bump.impact_score for item in group)
    )
    return RouteWarning(
        kind="continuous",
        message=f"{int(first.distance_along_route_m)}m 지점 연속 방지턱 구간",
        trigger_distances_m=alert_distances_m,
        distance_along_route_m=round(first.distance_along_route_m, 1),
        lat=first.bump.lat,
        lon=first.bump.lon,
        bump_count=len(group),
        impact_sum=round(impact_sum, 3),
        bump_ids=[item.bump.id for item in group],
    )


def _is_continuous(bump: SpeedBump) -> bool:
    return bump.continuous_yn.upper() == "Y" or bump.density_count > 1


def _dense_groups(matches: Sequence[MatchedBump]) -> List[List[MatchedBump]]:
    groups: List[List[MatchedBump]] = []
    current: List[MatchedBump] = []

    for match in matches:
        if match.bump.density_count <= 1:
            if current:
                groups.append(current)
                current = []
            continue

        if (
            current
            and match.distance_along_route_m
            - current[-1].distance_along_route_m
            > DENSE_GROUP_MAX_GAP_M
        ):
            groups.append(current)
            current = []
        current.append(match)

    if current:
        groups.append(current)
    return groups


def _dense_group_penalty(group: Sequence[MatchedBump]) -> float:
    if not group:
        return 0.0

    route_span_m = max(
        0.0,
        group[-1].distance_along_route_m
        - group[0].distance_along_route_m,
    )
    passage_distance_m = route_span_m + 2 * DENSE_SEGMENT_EDGE_MARGIN_M
    meter_penalty = max(item.bump.meter_penalty for item in group)
    height_ratio = max((item.bump.height_cm or 0.0) / 10.0 for item in group)
    density_count = max(
        len(group),
        max(item.bump.density_count for item in group),
    )
    maximum_penalty = density_count * height_ratio
    return min(passage_distance_m * meter_penalty, maximum_penalty)


def _independent_impact_score(bump: SpeedBump, uphill: bool) -> float:
    if (
        not uphill
        or not bump.slope_degree
        or bump.impact_score <= 0
    ):
        return bump.impact_score

    theta = math.radians(abs(bump.slope_degree))
    downhill_wtr = math.cos(theta) + SLOPE_WTR_RATIO * math.sin(theta)
    uphill_wtr = max(
        0.0,
        math.cos(theta) - SLOPE_WTR_RATIO * math.sin(theta),
    )
    if downhill_wtr <= 0:
        return bump.impact_score
    return bump.impact_score * uphill_wtr / downhill_wtr
