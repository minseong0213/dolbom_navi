from typing import List, Optional

from pydantic import BaseModel, Field


class Coordinate(BaseModel):
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)
    name: Optional[str] = None


class RouteRecommendRequest(BaseModel):
    origin: Coordinate
    destination: Coordinate
    search_options: List[int] = Field(
        default_factory=lambda: [0, 1, 2, 4, 10, 12]
    )
    buffer_m: Optional[float] = Field(default=None, gt=0, le=100)
    alert_distances_m: Optional[List[int]] = None
    exclude_virtual: bool = True
    min_alert_impact_score: Optional[float] = Field(default=None, ge=0)
    max_time_over_fastest_ratio: float = Field(default=0.15, ge=0, le=1)
    max_distance_over_shortest_ratio: Optional[float] = Field(
        default=None, ge=0, le=1
    )


class BumpMatch(BaseModel):
    id: int
    lat: float
    lon: float
    road_name: str
    address: str
    bump_type: str
    height_cm: Optional[float]
    width_cm: Optional[float]
    impact_score: float
    continuous_yn: str
    density_count: int
    distance_from_route_m: float
    distance_along_route_m: float


class RouteWarning(BaseModel):
    kind: str
    message: str
    trigger_distances_m: List[int]
    distance_along_route_m: float
    lat: float
    lon: float
    bump_count: int
    impact_sum: float
    bump_ids: List[int]


class RouteSummary(BaseModel):
    total_distance_m: float
    total_time_s: float
    total_fare: Optional[int] = None
    taxi_fare: Optional[int] = None


class CandidateRoute(BaseModel):
    id: str
    search_option: int
    search_option_label: str
    rank: int
    score: float
    summary: RouteSummary
    added_time_s: float
    added_distance_m: float
    bump_count: int
    impact_sum: float
    continuous_warning_count: int
    warnings: List[RouteWarning]
    matched_bumps: List[BumpMatch]
    polyline: List[Coordinate]


class RouteRecommendResponse(BaseModel):
    recommended_route_id: Optional[str]
    fastest_route_id: Optional[str]
    buffer_m: float
    candidate_count: int
    candidates: List[CandidateRoute]


class NearbyBumpsResponse(BaseModel):
    count: int
    bumps: List[BumpMatch]


class PlaceSearchResult(BaseModel):
    name: str
    address: str
    lat: float
    lon: float
    category: Optional[str] = None


class PlaceSearchResponse(BaseModel):
    query: str
    count: int
    places: List[PlaceSearchResult]
