import unittest

from app.models.schemas import RouteSummary
from app.services.route_deduplicator import deduplicate_routes, routes_are_similar
from app.services.tmap_client import TmapRoute


def _route(option: int, time_s: float, offset: float = 0.0) -> TmapRoute:
    return TmapRoute(
        search_option=option,
        summary=RouteSummary(total_distance_m=1000, total_time_s=time_s),
        polyline=[
            (37.0 + offset, 127.0),
            (37.0045 + offset, 127.0),
            (37.009 + offset, 127.0),
        ],
        raw_feature_count=3,
    )


class RouteDeduplicatorTest(unittest.TestCase):
    def test_route_id_does_not_change_with_travel_time(self):
        first = _route(0, 600)
        second = _route(2, 601)

        self.assertEqual(first.id, second.id)

    def test_merges_same_geometry_and_preserves_search_options(self):
        slower = _route(2, 601)
        faster = _route(4, 600)

        result = deduplicate_routes([slower, faster])

        self.assertEqual(len(result.routes), 1)
        self.assertEqual(result.merged_count, 1)
        self.assertEqual(result.routes[0].search_option, 4)
        self.assertEqual(result.routes[0].search_options, (2, 4))

    def test_keeps_routes_with_meaningfully_different_geometry(self):
        first = _route(0, 600)
        second = _route(2, 601, offset=0.001)

        self.assertFalse(routes_are_similar(first, second))
        self.assertEqual(len(deduplicate_routes([first, second]).routes), 2)

    def test_merges_routes_with_small_coordinate_noise(self):
        first = _route(0, 600)
        second = _route(2, 601, offset=0.00004)

        self.assertTrue(routes_are_similar(first, second))
        self.assertEqual(len(deduplicate_routes([first, second]).routes), 1)


if __name__ == "__main__":
    unittest.main()
