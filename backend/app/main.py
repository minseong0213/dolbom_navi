from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.core.config import get_settings
from app.services.elevation_client import ElevationClient
from app.services.speed_bump_repository import SpeedBumpRepository


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="Pregnant Navigation API",
        version="0.1.0",
        description="TMAP route reranking API for low-impact pregnancy navigation.",
        docs_url="/docs" if settings.enable_api_docs else None,
        redoc_url="/redoc" if settings.enable_api_docs else None,
        openapi_url="/openapi.json" if settings.enable_api_docs else None,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.on_event("startup")
    async def startup() -> None:
        repository = SpeedBumpRepository(settings.speed_bump_csv_path)
        repository.load()
        app.state.speed_bumps = repository
        app.state.elevation_client = ElevationClient(
            settings.elevation_api_url,
            enabled=settings.elevation_api_enabled,
            sample_offset_m=settings.elevation_sample_offset_m,
        )

    @app.get("/health")
    async def health() -> dict:
        repository = getattr(app.state, "speed_bumps", None)
        return {
            "ok": True,
            "speed_bump_count": len(repository.bumps) if repository else 0,
            "tmap_configured": bool(settings.tmap_app_key),
            "elevation_enabled": settings.elevation_api_enabled,
        }

    app.include_router(router, prefix="/api")
    return app


app = create_app()
