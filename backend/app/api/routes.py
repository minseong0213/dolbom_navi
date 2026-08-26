import asyncio
import logging
import time
from typing import List, Optional, Tuple

import httpx
from fastapi import APIRouter, HTTPException, Query, Request

from app.core.config import get_settings
from app.models.schemas import (
    NearbyBumpsResponse,
    PlaceSearchResponse,
    RouteOptionDiagnostic,
    RouteRecommendRequest,
    RouteRecommendResponse,
)
from app.services.elevation_client import ElevationClient
from app.services.route_deduplicator import deduplicate_routes
from app.services.route_scorer import (
    build_candidate_routes,
    select_eligible_routes,
    to_bump_match,
)
from app.services.speed_bump_repository import SpeedBumpRepository
from app.services.tmap_client import TmapClient, TmapRoute


router = APIRouter()
logger = logging.getLogger(__name__)


_ROUTE_CACHE_TTL_SECONDS = 300.0
_ROUTE_CACHE_MAX_ENTRIES = 256


def _repository(request: Request) -> SpeedBumpRepository:
    return request.app.state.speed_bumps


def _elevation_client(request: Request) -> ElevationClient:
    return request.app.state.elevation_client


def _tmap_client() -> TmapClient:
    settings = get_settings()
    return TmapClient(settings.tmap_app_key, settings.tmap_route_api_url)


def _route_cache_key(
    payload: RouteRecommendRequest,
    buffer_m: float,
    alert_distances_m: List[int],
    min_alert_impact_score: float,
) -> Tuple[object, ...]:
    return (
        round(payload.origin.lat, 6),
        round(payload.origin.lon, 6),
        round(payload.destination.lat, 6),
        round(payload.destination.lon, 6),
        tuple(payload.search_options),
        round(buffer_m, 2),
        tuple(alert_distances_m),
        payload.exclude_virtual,
        round(min_alert_impact_score, 2),
        round(payload.max_time_over_fastest_ratio, 3),
        (
            round(payload.max_distance_over_shortest_ratio, 3)
            if payload.max_distance_over_shortest_ratio is not None
            else None
        ),
    )


async def _fetch_route_option(
    tmap_client: TmapClient,
    client: httpx.AsyncClient,
    payload: RouteRecommendRequest,
    search_option: int,
) -> Tuple[Optional[TmapRoute], RouteOptionDiagnostic]:
    started = time.perf_counter()
    try:
        route = await tmap_client.get_car_route(
            payload.origin,
            payload.destination,
            search_option,
            client=client,
        )
    except Exception as exc:  # noqa: BLE001
        elapsed_ms = (time.perf_counter() - started) * 1000
        logger.warning("TMAP route option %s failed: %s", search_option, exc)
        return None, RouteOptionDiagnostic(
            search_option=search_option,
            status="error",
            elapsed_ms=round(elapsed_ms, 1),
            error=str(exc),
        )

    elapsed_ms = (time.perf_counter() - started) * 1000
    return route, RouteOptionDiagnostic(
        search_option=search_option,
        status="success",
        elapsed_ms=round(elapsed_ms, 1),
    )


async def _fetch_route_options(
    tmap_client: TmapClient,
    payload: RouteRecommendRequest,
) -> Tuple[List[TmapRoute], List[RouteOptionDiagnostic]]:
    timeout = httpx.Timeout(15.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        results = await asyncio.gather(
            *(
                _fetch_route_option(tmap_client, client, payload, search_option)
                for search_option in dict.fromkeys(payload.search_options)
            )
        )
    routes = [route for route, _ in results if route is not None]
    diagnostics = [diagnostic for _, diagnostic in results]
    return routes, diagnostics


@router.get("/places/search", response_model=PlaceSearchResponse)
async def search_places(
    q: str = Query(..., min_length=2, max_length=80),
    count: int = Query(8, ge=1, le=20),
) -> PlaceSearchResponse:
    tmap_client = _tmap_client()
    try:
        places = await tmap_client.search_places(q, count=count)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=502,
            detail={"message": "TMAP place search failed.", "error": str(exc)},
        ) from exc

    return PlaceSearchResponse(query=q, count=len(places), places=places)


@router.post("/routes/recommend", response_model=RouteRecommendResponse)
async def recommend_routes(
    payload: RouteRecommendRequest, request: Request
) -> RouteRecommendResponse:
    request_started = time.perf_counter()
    settings = get_settings()
    buffer_m = payload.buffer_m or settings.default_route_buffer_m
    alert_distances_m = payload.alert_distances_m or settings.default_alert_distances_m
    min_alert_impact_score = (
        payload.min_alert_impact_score
        if payload.min_alert_impact_score is not None
        else settings.default_min_alert_impact_score
    )
    repository = _repository(request)
    tmap_client = _tmap_client()

    cache = getattr(request.app.state, "route_recommend_cache", None)
    if cache is None:
        cache = {}
        request.app.state.route_recommend_cache = cache
    cache_key = _route_cache_key(
        payload,
        buffer_m,
        alert_distances_m,
        min_alert_impact_score,
    )
    cached = cache.get(cache_key)
    now = time.monotonic()
    if cached is not None:
        cached_at, cached_response = cached
        if now - cached_at < _ROUTE_CACHE_TTL_SECONDS:
            return cached_response
        cache.pop(cache_key, None)

    routes, option_diagnostics = await _fetch_route_options(tmap_client, payload)
    errors = [
        f"{item.search_option}: {item.error}"
        for item in option_diagnostics
        if item.status == "error"
    ]

    if not routes:
        raise HTTPException(
            status_code=502,
            detail={"message": "No TMAP route candidates were returned.", "errors": errors},
        )

    raw_candidate_count = len(routes)
    deduplication = deduplicate_routes(routes)
    unique_routes = deduplication.routes
    eligibility = select_eligible_routes(
        unique_routes,
        max_time_over_fastest_ratio=payload.max_time_over_fastest_ratio,
        max_distance_over_shortest_ratio=payload.max_distance_over_shortest_ratio,
    )
    eligible_routes = eligibility.routes

    matches_by_route_id = {
        route.id: repository.match_route(
            route.polyline,
            buffer_m=buffer_m,
            exclude_virtual=payload.exclude_virtual,
            excluded_polylines=route.speed_bump_excluded_polylines,
        )
        for route in eligible_routes
    }
    try:
        uphill_bump_ids_by_route_id = await _elevation_client(
            request
        ).classify_uphill_bumps(eligible_routes, matches_by_route_id)
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "Elevation lookup failed; using CSV downhill scores: %s",
            exc,
        )
        uphill_bump_ids_by_route_id = {}

    candidates = build_candidate_routes(
        eligible_routes,
        matches_by_route_id,
        alert_distances_m=alert_distances_m,
        min_alert_impact_score=min_alert_impact_score,
        max_time_over_fastest_ratio=payload.max_time_over_fastest_ratio,
        max_distance_over_shortest_ratio=payload.max_distance_over_shortest_ratio,
        uphill_bump_ids_by_route_id=uphill_bump_ids_by_route_id,
        routes_are_eligible=True,
        baseline_fastest_time_s=eligibility.fastest_time_s,
        baseline_shortest_distance_m=eligibility.shortest_distance_m,
    )
    fastest_route = min(unique_routes, key=lambda item: item.summary.total_time_s)
    fastest = next(
        (candidate for candidate in candidates if candidate.id == fastest_route.id),
        min(candidates, key=lambda item: item.summary.total_time_s),
    )
    recommended = candidates[0] if candidates else None

    response = RouteRecommendResponse(
        recommended_route_id=recommended.id if recommended else None,
        fastest_route_id=fastest.id if candidates else None,
        buffer_m=buffer_m,
        raw_candidate_count=raw_candidate_count,
        deduplicated_candidate_count=len(unique_routes),
        eligible_candidate_count=len(candidates),
        candidate_count=len(candidates),
        option_errors=errors,
        option_diagnostics=option_diagnostics,
        processing_time_ms=round((time.perf_counter() - request_started) * 1000, 1),
        candidates=candidates,
    )
    if len(cache) >= _ROUTE_CACHE_MAX_ENTRIES:
        cache.pop(next(iter(cache)))
    cache[cache_key] = (now, response)
    return response


@router.get("/bumps/nearby", response_model=NearbyBumpsResponse)
async def nearby_bumps(
    request: Request,
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    radius_m: float = Query(300, gt=0, le=5000),
) -> NearbyBumpsResponse:
    repository = _repository(request)
    matches = repository.nearby(lat, lon, radius_m)
    return NearbyBumpsResponse(
        count=len(matches),
        bumps=[to_bump_match(item) for item in matches],
    )
