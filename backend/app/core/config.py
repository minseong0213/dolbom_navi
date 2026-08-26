from functools import lru_cache
import os
from pathlib import Path
from typing import List

from dotenv import load_dotenv


load_dotenv()


class Settings:
    def __init__(self) -> None:
        self.tmap_app_key = os.getenv("TMAP_APP_KEY", "").strip()
        self.tmap_route_api_url = os.getenv(
            "TMAP_ROUTE_API_URL", "https://apis.openapi.sk.com/tmap/routes"
        ).strip()
        self.elevation_api_url = os.getenv(
            "ELEVATION_API_URL",
            "https://api.open-elevation.com/api/v1/lookup",
        ).strip()
        self.elevation_api_enabled = self._parse_bool(
            os.getenv("ELEVATION_API_ENABLED", "true")
        )
        self.elevation_sample_offset_m = float(
            os.getenv("ELEVATION_SAMPLE_OFFSET_M", "20")
        )
        self.speed_bump_csv_path = Path(
            os.getenv(
                "SPEED_BUMP_CSV_PATH",
                r"E:\전국방지턱\전국_방지턱_좌표검증완료_유형수정본.csv",
            )
        )
        self.default_route_buffer_m = float(os.getenv("DEFAULT_ROUTE_BUFFER_M", "10"))
        self.default_min_alert_impact_score = float(
            os.getenv("DEFAULT_MIN_ALERT_IMPACT_SCORE", "0.75")
        )
        self.default_alert_distances_m = self._parse_int_list(
            os.getenv("DEFAULT_ALERT_DISTANCES_M", "300,100")
        )
        self.enable_api_docs = self._parse_bool(
            os.getenv("ENABLE_API_DOCS", "true")
        )

    @staticmethod
    def _parse_int_list(value: str) -> List[int]:
        parsed: List[int] = []
        for item in value.split(","):
            item = item.strip()
            if item:
                parsed.append(int(item))
        return parsed or [300, 100]

    @staticmethod
    def _parse_bool(value: str) -> bool:
        return value.strip().lower() in {"1", "true", "yes", "on"}


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
