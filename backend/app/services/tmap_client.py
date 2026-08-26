import asyncio
from dataclasses import dataclass, field
import hashlib
from json import JSONDecodeError
from typing import Any, Dict, List, Optional, Tuple

import httpx

from app.models.schemas import Coordinate, PlaceSearchResult, RouteSummary


LatLon = Tuple[float, float]


SEARCH_OPTION_LABELS = {
    0: "교통최적+추천",
    1: "교통최적+무료우선",
    2: "교통최적+최소시간",
    3: "교통최적+초보",
    4: "교통최적+고속도로우선",
    10: "최단거리+유/무료",
    12: "이륜차도로우선",
    19: "교통최적+어린이보호구역 회피",
}

AUTOMOBILE_ONLY_ROAD_TYPES = {0, 1}
TUNNEL_NAME_KEYWORDS = ("터널", "지하차도", "지하도로")
TRANSIENT_HTTP_STATUSES = {408, 425, 429, 500, 502, 503, 504}


@dataclass(frozen=True)
class TmapRouteSegment:
    polyline: List[LatLon]
    name: str
    road_type: Optional[int]
    facility_type: Optional[int]
    distance_m: float
    time_s: float

    @property
    def excludes_speed_bumps(self) -> bool:
        return self.road_type in AUTOMOBILE_ONLY_ROAD_TYPES

    @property
    def is_tunnel(self) -> bool:
        return any(keyword in self.name for keyword in TUNNEL_NAME_KEYWORDS)


@dataclass(frozen=True)
class TmapRoute:
    search_option: int
    summary: RouteSummary
    polyline: List[LatLon]
    raw_feature_count: int
    segments: List[TmapRouteSegment] = field(default_factory=list)
    source_search_options: Tuple[int, ...] = field(default_factory=tuple)

    @property
    def id(self) -> str:
        hasher = hashlib.sha1()
        for lat, lon in self.polyline[:: max(1, len(self.polyline) // 50)]:
            hasher.update(f"{lat:.5f},{lon:.5f};".encode("ascii"))
        if self.polyline:
            lat, lon = self.polyline[-1]
            hasher.update(f"{lat:.5f},{lon:.5f};".encode("ascii"))
        return hasher.hexdigest()[:12]

    @property
    def label(self) -> str:
        return SEARCH_OPTION_LABELS.get(self.search_option, f"탐색옵션 {self.search_option}")

    @property
    def speed_bump_excluded_polylines(self) -> List[List[LatLon]]:
        return [
            segment.polyline
            for segment in self.segments
            if segment.excludes_speed_bumps
        ]

    @property
    def search_options(self) -> Tuple[int, ...]:
        return self.source_search_options or (self.search_option,)

    @property
    def expressway_distance_m(self) -> float:
        return sum(
            segment.distance_m for segment in self.segments if segment.excludes_speed_bumps
        )

    @property
    def tunnel_distance_m(self) -> float:
        return sum(segment.distance_m for segment in self.segments if segment.is_tunnel)

    @property
    def road_types(self) -> List[int]:
        return sorted(
            {segment.road_type for segment in self.segments if segment.road_type is not None}
        )

    @property
    def facility_types(self) -> List[int]:
        return sorted(
            {
                segment.facility_type
                for segment in self.segments
                if segment.facility_type is not None
            }
        )


class TmapClient:
    def __init__(self, app_key: str, route_api_url: str) -> None:
        self.app_key = app_key
        self.route_api_url = route_api_url

    async def get_car_route(
        self,
        origin: Coordinate,
        destination: Coordinate,
        search_option: int,
        client: Optional[httpx.AsyncClient] = None,
    ) -> TmapRoute:
        if not self.app_key:
            raise RuntimeError("TMAP_APP_KEY is not configured.")

        payload = {
            "startX": str(origin.lon),
            "startY": str(origin.lat),
            "endX": str(destination.lon),
            "endY": str(destination.lat),
            "reqCoordType": "WGS84GEO",
            "resCoordType": "WGS84GEO",
            "searchOption": str(search_option),
            "trafficInfo": "N",
            "totalValue": "1",
        }
        if origin.name:
            payload["startName"] = origin.name
        if destination.name:
            payload["endName"] = destination.name

        headers = {
            "appKey": self.app_key,
            "Accept": "application/json",
            "Content-Type": "application/x-www-form-urlencoded",
        }
        params = {"version": "1", "format": "json"}

        if client is not None:
            return await self._request_car_route(
                client, params, payload, headers, search_option
            )

        async with httpx.AsyncClient(timeout=15.0) as owned_client:
            return await self._request_car_route(
                owned_client, params, payload, headers, search_option
            )

    async def _request_car_route(
        self,
        client: httpx.AsyncClient,
        params: Dict[str, str],
        payload: Dict[str, str],
        headers: Dict[str, str],
        search_option: int,
    ) -> TmapRoute:
        last_error: Optional[Exception] = None
        for attempt in range(2):
            try:
                response = await client.post(
                    self.route_api_url,
                    params=params,
                    data=payload,
                    headers=headers,
                )
            except (httpx.TimeoutException, httpx.TransportError) as exc:
                last_error = exc
                if attempt == 0:
                    await asyncio.sleep(0.25)
                    continue
                raise RuntimeError(f"TMAP route request failed: {exc}") from exc

            if response.status_code in TRANSIENT_HTTP_STATUSES and attempt == 0:
                await asyncio.sleep(0.25)
                continue
            if response.status_code >= 400:
                safe_body = response.text[:500]
                raise RuntimeError(
                    f"TMAP route request failed: {response.status_code} {safe_body}"
                )
            return parse_tmap_route(response.json(), search_option)

        raise RuntimeError(f"TMAP route request failed: {last_error}")

    async def search_places(self, query: str, count: int = 10) -> List[PlaceSearchResult]:
        if not self.app_key:
            raise RuntimeError("TMAP_APP_KEY is not configured.")

        params = {
            "version": "1",
            "format": "json",
            "searchKeyword": query,
            "resCoordType": "WGS84GEO",
            "count": str(count),
        }
        headers = {
            "appKey": self.app_key,
            "Accept": "application/json",
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                "https://apis.openapi.sk.com/tmap/pois",
                params=params,
                headers=headers,
            )

        if response.status_code >= 400:
            safe_body = response.text[:500]
            raise RuntimeError(
                f"TMAP place search failed: {response.status_code} {safe_body}"
            )

        try:
            data = response.json()
        except JSONDecodeError:
            return []

        search_info = data.get("searchPoiInfo") or {}
        pois = ((search_info.get("pois") or {}).get("poi")) or []
        if isinstance(pois, dict):
            pois = [pois]

        places: List[PlaceSearchResult] = []
        for item in pois:
            place = _parse_place(item)
            if place is not None:
                places.append(place)
        return places


def parse_tmap_route(data: Dict[str, Any], search_option: int) -> TmapRoute:
    features = data.get("features") or []
    polyline: List[LatLon] = []
    segments: List[TmapRouteSegment] = []
    summary_props: Dict[str, Any] = {}
    distance_sum = 0.0
    time_sum = 0.0

    for feature in features:
        geometry = feature.get("geometry") or {}
        properties = feature.get("properties") or {}

        if not summary_props and (
            "totalDistance" in properties or "totalTime" in properties
        ):
            summary_props = properties

        if geometry.get("type") == "LineString":
            segment_polyline = _parse_line(geometry.get("coordinates") or [])
            _append_route_line(polyline, segment_polyline)
            _append_segment(segments, segment_polyline, properties)
            distance_sum += _to_float(properties.get("distance"))
            time_sum += _to_float(properties.get("time"))
        elif geometry.get("type") == "MultiLineString":
            for line in geometry.get("coordinates") or []:
                segment_polyline = _parse_line(line)
                _append_route_line(polyline, segment_polyline)
                _append_segment(segments, segment_polyline, properties)
            distance_sum += _to_float(properties.get("distance"))
            time_sum += _to_float(properties.get("time"))

    if not polyline:
        raise RuntimeError("TMAP response did not include a route polyline.")

    total_distance = _to_float(summary_props.get("totalDistance")) or distance_sum
    total_time = _to_float(summary_props.get("totalTime")) or time_sum

    summary = RouteSummary(
        total_distance_m=total_distance,
        total_time_s=total_time,
        total_fare=_to_optional_int(summary_props.get("totalFare")),
        taxi_fare=_to_optional_int(summary_props.get("taxiFare")),
    )
    return TmapRoute(
        search_option=search_option,
        summary=summary,
        polyline=polyline,
        raw_feature_count=len(features),
        segments=segments,
    )


def _parse_line(coordinates: Any) -> List[LatLon]:
    parsed: List[LatLon] = []
    for coord in coordinates or []:
        lat_lon = _coord_to_lat_lon(coord)
        if lat_lon and (not parsed or parsed[-1] != lat_lon):
            parsed.append(lat_lon)
    return parsed


def _append_route_line(route: List[LatLon], line: List[LatLon]) -> None:
    for lat_lon in line:
        if not route or route[-1] != lat_lon:
            route.append(lat_lon)


def _append_segment(
    segments: List[TmapRouteSegment],
    polyline: List[LatLon],
    properties: Dict[str, Any],
) -> None:
    if not polyline:
        return
    segments.append(
        TmapRouteSegment(
            polyline=polyline,
            name=str(properties.get("name") or "").strip(),
            road_type=_to_optional_int(properties.get("roadType")),
            facility_type=_to_optional_int(properties.get("facilityType")),
            distance_m=_to_float(properties.get("distance")),
            time_s=_to_float(properties.get("time")),
        )
    )


def _coord_to_lat_lon(coord: Any) -> Optional[LatLon]:
    if not isinstance(coord, list) or len(coord) < 2:
        return None
    try:
        lon = float(coord[0])
        lat = float(coord[1])
    except (TypeError, ValueError):
        return None
    return lat, lon


def _parse_place(item: Dict[str, Any]) -> Optional[PlaceSearchResult]:
    lat = _to_float(item.get("frontLat")) or _to_float(item.get("noorLat"))
    lon = _to_float(item.get("frontLon")) or _to_float(item.get("noorLon"))
    if not lat or not lon:
        return None

    address_parts = [
        item.get("upperAddrName"),
        item.get("middleAddrName"),
        item.get("lowerAddrName"),
        item.get("detailAddrName"),
    ]
    address = " ".join(str(part).strip() for part in address_parts if str(part or "").strip())
    return PlaceSearchResult(
        name=str(item.get("name") or "").strip(),
        address=address,
        lat=lat,
        lon=lon,
        category=str(item.get("bizCatName") or item.get("middleBizName") or "").strip()
        or None,
    )


def _to_float(value: Any) -> float:
    if value is None or value == "":
        return 0.0
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _to_optional_int(value: Any) -> Optional[int]:
    if value is None or value == "":
        return None
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return None
