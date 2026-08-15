import unittest

from app.models.schemas import RouteSummary
from app.services.elevation_client import ElevationClient
from app.services.speed_bump_repository import MatchedBump, SpeedBump
from app.services.tmap_client import TmapRoute


class StubElevationClient(ElevationClient):
    async def _lookup_elevations(self, coordinates):
        return {
            key: coordinate[0] * 1000
            for key, coordinate in coordinates.items()
        }


class ElevationClientTest(unittest.IsolatedAsyncioTestCase):
    async def test_classifies_uphill_from_route_direction(self):
        route = TmapRoute(
            search_option=0,
            summary=RouteSummary(total_distance_m=1200, total_time_s=300),
            polyline=[(37.0, 127.0), (37.01, 127.0)],
            raw_feature_count=1,
        )
        bump = SpeedBump(
            id=1,
            province="서울특별시",
            district="중구",
            road_name="테스트로",
            address="테스트 주소",
            bump_type="원호형",
            height_cm=10.0,
            width_cm=360.0,
            lat=37.005,
            lon=127.0,
            continuous_yn="N",
            separated_sidewalk_yn="N",
            density_count=1,
            slope_degree=5.0,
            impact_score=1.0,
            meter_penalty=0.0,
        )
        match = MatchedBump(
            bump=bump,
            distance_from_route_m=0,
            distance_along_route_m=550,
        )
        client = StubElevationClient(
            "https://example.invalid/elevation",
            enabled=True,
            sample_offset_m=20,
        )

        uphill = await client.classify_uphill_bumps(
            [route],
            {route.id: [match]},
        )

        self.assertEqual(uphill, {route.id: {bump.id}})

    async def test_skips_elevation_when_disabled(self):
        client = StubElevationClient(
            "https://example.invalid/elevation",
            enabled=False,
        )

        self.assertEqual(await client.classify_uphill_bumps([], {}), {})
