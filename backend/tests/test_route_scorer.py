import unittest

from app.models.schemas import RouteSummary
from app.services.route_scorer import build_candidate_routes
from app.services.speed_bump_repository import MatchedBump, SpeedBump
from app.services.tmap_client import TmapRoute


def _route(option: int, time_s: float, distance_m: float) -> TmapRoute:
    offset = option / 1000
    return TmapRoute(
        search_option=option,
        summary=RouteSummary(
            total_distance_m=distance_m,
            total_time_s=time_s,
        ),
        polyline=[(37.0 + offset, 127.0), (37.01 + offset, 127.01)],
        raw_feature_count=1,
    )


def _match(
    bump_id: int,
    impact_score: float,
    along_m: float,
    *,
    continuous: bool = False,
    density_count: int = 1,
    height_cm: float = 10.0,
    meter_penalty: float = 0.0,
    slope_degree: float = 0.0,
) -> MatchedBump:
    return MatchedBump(
        bump=SpeedBump(
            id=bump_id,
            province="서울특별시",
            district="중구",
            road_name="테스트로",
            address="테스트 주소",
            bump_type="원호형",
            height_cm=height_cm,
            width_cm=360.0,
            lat=37.0,
            lon=127.0,
            continuous_yn="Y" if continuous else "N",
            separated_sidewalk_yn="N",
            density_count=density_count,
            slope_degree=slope_degree,
            impact_score=impact_score,
            meter_penalty=meter_penalty,
        ),
        distance_from_route_m=5.0,
        distance_along_route_m=along_m,
    )


def _build(
    routes,
    matches,
    *,
    time_ratio=0.15,
    distance_ratio=None,
    uphill=None,
):
    return build_candidate_routes(
        routes,
        matches,
        alert_distances_m=[300, 100],
        min_alert_impact_score=0.0,
        max_time_over_fastest_ratio=time_ratio,
        max_distance_over_shortest_ratio=distance_ratio,
        uphill_bump_ids_by_route_id=uphill,
    )


class RouteScorerTest(unittest.TestCase):
    def test_uses_100_point_comfort_score_and_sorts_descending(self):
        rough = _route(0, 600, 5000)
        safe = _route(2, 630, 5200)

        candidates = _build(
            [rough, safe],
            {
                rough.id: [_match(1, 8.0, 100)],
                safe.id: [_match(2, 3.0, 100)],
            },
        )

        self.assertEqual([candidate.id for candidate in candidates], [safe.id, rough.id])
        self.assertEqual(candidates[0].raw_score, 97.0)
        self.assertEqual(candidates[1].raw_score, 92.0)
        self.assertGreater(candidates[0].score, candidates[1].score)

    def test_does_not_add_match_count_or_continuous_weight(self):
        route = _route(0, 600, 5000)

        candidate = _build(
            [route],
            {
                route.id: [
                    _match(1, 1.0, 100, continuous=True),
                    _match(2, 2.0, 150, continuous=True),
                ]
            },
        )[0]

        self.assertEqual(candidate.raw_score, 97.0)
        self.assertEqual(candidate.continuous_warning_count, 1)

    def test_dense_segment_uses_distance_rate_and_maximum_cap(self):
        route = _route(0, 600, 5000)

        candidate = _build(
            [route],
            {
                route.id: [
                    _match(
                        1,
                        0.0,
                        100,
                        density_count=2,
                        meter_penalty=0.0625,
                    ),
                    _match(
                        2,
                        0.0,
                        200,
                        density_count=2,
                        meter_penalty=0.0625,
                    ),
                ]
            },
        )[0]

        self.assertEqual(candidate.impact_sum, 2.0)
        self.assertEqual(candidate.raw_score, 98.0)
        self.assertEqual(candidate.continuous_warning_count, 1)
        self.assertEqual(candidate.warnings[0].impact_sum, 2.0)

    def test_uphill_direction_reduces_independent_impact(self):
        route = _route(0, 600, 5000)
        match = _match(1, 2.0, 100, slope_degree=10.0)

        downhill = _build([route], {route.id: [match]})[0]
        uphill = _build(
            [route],
            {route.id: [match]},
            uphill={route.id: {1}},
        )[0]

        self.assertEqual(downhill.impact_sum, 2.0)
        self.assertLess(uphill.impact_sum, downhill.impact_sum)
        self.assertGreater(uphill.score, downhill.score)

    def test_time_and_distance_do_not_change_score(self):
        fast = _route(0, 600, 5000)
        slower = _route(2, 660, 5900)
        matches = {
            fast.id: [_match(1, 2.0, 100)],
            slower.id: [_match(2, 2.0, 100)],
        }

        candidates = _build([slower, fast], matches)

        self.assertEqual(len(candidates), 2)
        self.assertEqual(candidates[0].raw_score, 98.0)
        self.assertEqual(candidates[1].raw_score, 98.0)
        self.assertEqual(candidates[0].id, fast.id)

    def test_equal_impact_prefers_fewer_bumps_before_travel_time(self):
        fast = _route(0, 600, 5000)
        fewer_bumps = _route(2, 606, 5100)
        matches = {
            fast.id: [_match(1, 1.0, 100), _match(2, 1.0, 200)],
            fewer_bumps.id: [_match(3, 2.0, 100)],
        }

        candidates = _build([fast, fewer_bumps], matches)

        self.assertEqual(candidates[0].id, fewer_bumps.id)
        self.assertEqual(candidates[0].bump_count, 1)
        self.assertEqual(candidates[1].bump_count, 2)

    def test_excludes_routes_outside_time_allowance(self):
        fast = _route(0, 600, 5000)
        too_slow = _route(2, 700, 5200)

        candidates = _build(
            [fast, too_slow],
            {
                fast.id: [_match(1, 5.0, 100)],
                too_slow.id: [],
            },
        )

        self.assertEqual([candidate.id for candidate in candidates], [fast.id])

    def test_applies_optional_distance_ratio_filter(self):
        shortest = _route(0, 600, 5000)
        too_long = _route(2, 620, 6100)

        candidates = _build(
            [shortest, too_long],
            {shortest.id: [], too_long.id: []},
            distance_ratio=0.20,
        )

        self.assertEqual([candidate.id for candidate in candidates], [shortest.id])

    def test_clamps_comfort_score_at_zero(self):
        route = _route(0, 600, 5000)

        candidate = _build(
            [route],
            {route.id: [_match(1, 120.0, 100)]},
        )[0]

        self.assertEqual(candidate.raw_score, 0.0)
        self.assertEqual(candidate.distance_normalized_score, 0.0)


if __name__ == "__main__":
    unittest.main()
