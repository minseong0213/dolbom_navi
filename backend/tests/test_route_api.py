import asyncio
import unittest

from app.api.routes import _fetch_route_options
from app.models.schemas import Coordinate, RouteRecommendRequest, RouteSummary
from app.services.tmap_client import TmapRoute


class _ConcurrentTmapClient:
    def __init__(self) -> None:
        self.active = 0
        self.max_active = 0

    async def get_car_route(self, origin, destination, search_option, client=None):
        self.active += 1
        self.max_active = max(self.max_active, self.active)
        await asyncio.sleep(0.01)
        self.active -= 1
        return TmapRoute(
            search_option=search_option,
            summary=RouteSummary(
                total_distance_m=1000 + search_option,
                total_time_s=600 + search_option,
            ),
            polyline=[(origin.lat, origin.lon), (destination.lat, destination.lon)],
            raw_feature_count=1,
        )


class RouteApiTest(unittest.IsolatedAsyncioTestCase):
    async def test_fetches_search_options_concurrently(self):
        client = _ConcurrentTmapClient()
        payload = RouteRecommendRequest(
            origin=Coordinate(lat=37.0, lon=127.0),
            destination=Coordinate(lat=37.1, lon=127.1),
            search_options=[0, 1, 2],
        )

        routes, diagnostics = await _fetch_route_options(client, payload)

        self.assertEqual(len(routes), 3)
        self.assertEqual(client.max_active, 3)
        self.assertEqual([item.status for item in diagnostics], ["success"] * 3)


if __name__ == "__main__":
    unittest.main()
