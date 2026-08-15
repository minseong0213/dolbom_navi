import unittest

from app.services.tmap_client import parse_tmap_route


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


if __name__ == "__main__":
    unittest.main()
