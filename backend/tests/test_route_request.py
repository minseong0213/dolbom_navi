import unittest

from app.models.schemas import Coordinate, RouteRecommendRequest


class RouteRecommendRequestTest(unittest.TestCase):
    def test_uses_documented_six_search_options(self):
        request = RouteRecommendRequest(
            origin=Coordinate(lat=37.0, lon=127.0),
            destination=Coordinate(lat=37.1, lon=127.1),
        )

        self.assertEqual(request.search_options, [0, 1, 2, 4, 10, 12])


if __name__ == "__main__":
    unittest.main()
