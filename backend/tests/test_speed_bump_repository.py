import unittest
from pathlib import Path

from app.services.speed_bump_repository import SpeedBump, SpeedBumpRepository


def _bump(bump_id: int, lat: float, lon: float) -> SpeedBump:
    return SpeedBump(
        id=bump_id,
        province="서울특별시",
        district="중구",
        road_name="테스트로",
        address="테스트 주소",
        bump_type="원호형",
        height_cm=10,
        width_cm=360,
        lat=lat,
        lon=lon,
        continuous_yn="N",
        separated_sidewalk_yn="N",
        density_count=1,
        slope_degree=0,
        impact_score=1,
        meter_penalty=0,
    )


class SpeedBumpRepositoryTest(unittest.TestCase):
    def test_excludes_bump_when_nearest_route_segment_is_automobile_only(self):
        repository = SpeedBumpRepository(Path("unused.csv"))
        repository.bumps = [
            _bump(1, 37.00004, 127.0005),
            _bump(2, 37.0005, 127.00104),
        ]
        repository._build_grid()
        route = [(37.0, 127.0), (37.0, 127.001), (37.001, 127.001)]
        automobile_only = [[(37.0, 127.0), (37.0, 127.001)]]

        matches = repository.match_route(
            route,
            buffer_m=30,
            exclude_virtual=True,
            excluded_polylines=automobile_only,
        )

        self.assertEqual([match.bump.id for match in matches], [2])


if __name__ == "__main__":
    unittest.main()
