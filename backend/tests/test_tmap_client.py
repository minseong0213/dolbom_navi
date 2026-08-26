import unittest

import httpx

from app.models.schemas import Coordinate
from app.services.tmap_client import TmapClient, parse_tmap_route


class TmapClientTest(unittest.TestCase):
    def test_preserves_route_segment_road_metadata(self):
        route = parse_tmap_route(
            {
                "features": [
                    {
                        "geometry": {"type": "Point", "coordinates": [127, 37]},
                        "properties": {"totalDistance": 200, "totalTime": 30},
                    },
                    {
                        "geometry": {
                            "type": "LineString",
                            "coordinates": [[127, 37], [127.001, 37]],
                        },
                        "properties": {
                            "name": "테스트 고속도로",
                            "roadType": 0,
                            "facilityType": 1,
                            "distance": 100,
                            "time": 10,
                        },
                    },
                    {
                        "geometry": {
                            "type": "LineString",
                            "coordinates": [[127.001, 37], [127.001, 37.001]],
                        },
                        "properties": {
                            "name": "테스트 일반도로",
                            "roadType": 5,
                            "facilityType": 0,
                            "distance": 100,
                            "time": 20,
                        },
                    },
                ]
            },
            search_option=0,
        )

        self.assertEqual(len(route.segments), 2)
        self.assertEqual(route.segments[0].name, "테스트 고속도로")
        self.assertEqual(route.segments[0].road_type, 0)
        self.assertTrue(route.segments[0].excludes_speed_bumps)
        self.assertFalse(route.segments[1].excludes_speed_bumps)
        self.assertEqual(
            route.speed_bump_excluded_polylines,
            [[(37.0, 127.0), (37.0, 127.001)]],
        )
        self.assertEqual(route.expressway_distance_m, 100)
        self.assertEqual(route.road_types, [0, 5])
        self.assertEqual(route.facility_types, [0, 1])


class TmapClientRetryTest(unittest.IsolatedAsyncioTestCase):
    async def test_retries_once_after_transient_failure(self):
        attempts = 0

        def handler(request):
            nonlocal attempts
            attempts += 1
            if attempts == 1:
                return httpx.Response(503, text="temporary")
            return httpx.Response(
                200,
                json={
                    "features": [
                        {
                            "geometry": {"type": "Point", "coordinates": [127, 37]},
                            "properties": {"totalDistance": 100, "totalTime": 10},
                        },
                        {
                            "geometry": {
                                "type": "LineString",
                                "coordinates": [[127, 37], [127.001, 37]],
                            },
                            "properties": {"distance": 100, "time": 10},
                        },
                    ]
                },
            )

        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            route = await TmapClient("test-key", "https://example.test/routes").get_car_route(
                Coordinate(lat=37, lon=127),
                Coordinate(lat=37, lon=127.001),
                0,
                client=client,
            )

        self.assertEqual(attempts, 2)
        self.assertEqual(route.summary.total_distance_m, 100)


if __name__ == "__main__":
    unittest.main()
