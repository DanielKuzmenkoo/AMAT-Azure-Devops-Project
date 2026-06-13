"""FastAPI application: health, locations, and weather endpoints.

Exception handlers convert internal/typed errors into clean JSON responses so
no stack traces or third-party details leak to clients. All error responses
share the shape ``{"error": "<message>"}``.
"""
from __future__ import annotations

import logging
import os
from pathlib import Path

from fastapi import FastAPI, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from .open_meteo import UpstreamError, UpstreamTimeoutError
from .schemas import ErrorResponse, LocationsResponse, WeatherResponse
from .service import CityNotFoundError, get_locations, get_weather


def _configure_observability() -> None:
    """Wire up Application Insights via the Azure Monitor OpenTelemetry distro.

    Runs before the app is created so FastAPI request auto-instrumentation
    applies. It is a no-op unless APPLICATIONINSIGHTS_CONNECTION_STRING is set,
    so local development, CI, and tests run with no telemetry and no extra
    dependencies exercised. The Container App injects the connection string and
    sets OTEL_SERVICE_NAME to the per-environment cloud role name.

    Telemetry is best-effort: any failure here (missing package, bad connection
    string, unreachable endpoint) is logged and swallowed so observability can
    never take the app down.
    """
    if not os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
        return
    try:
        from azure.monitor.opentelemetry import configure_azure_monitor
        from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

        configure_azure_monitor()  # auto-instruments FastAPI; exports to App Insights
        HTTPXClientInstrumentor().instrument()  # trace outbound Open-Meteo calls
    except Exception:  # noqa: BLE001 - telemetry must never crash the app
        logging.getLogger(__name__).warning(
            "Application Insights setup failed; continuing without telemetry.",
            exc_info=True,
        )


_configure_observability()

app = FastAPI(
    title="Weather API",
    description="A small weather demo backed by Open-Meteo (no API key required).",
    version="1.0.0",
)


class BadRequestError(Exception):
    """Raised for invalid client input (e.g. missing or empty city)."""


def _error(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(status_code=status_code, content=ErrorResponse(error=message).model_dump())


@app.exception_handler(BadRequestError)
async def _bad_request_handler(_: Request, exc: BadRequestError) -> JSONResponse:
    return _error(400, str(exc))


@app.exception_handler(RequestValidationError)
async def _validation_handler(_: Request, __: RequestValidationError) -> JSONResponse:
    return _error(400, "Invalid request parameters")


@app.exception_handler(StarletteHTTPException)
async def _http_exception_handler(_: Request, exc: StarletteHTTPException) -> JSONResponse:
    # Keep all errors (including 404 for unknown routes) in the {"error": ...} shape.
    return _error(exc.status_code, str(exc.detail))


@app.exception_handler(CityNotFoundError)
async def _city_not_found_handler(_: Request, exc: CityNotFoundError) -> JSONResponse:
    return _error(404, str(exc))


@app.exception_handler(UpstreamTimeoutError)
async def _timeout_handler(_: Request, exc: UpstreamTimeoutError) -> JSONResponse:
    return _error(504, str(exc))


@app.exception_handler(UpstreamError)
async def _upstream_handler(_: Request, exc: UpstreamError) -> JSONResponse:
    return _error(502, str(exc))


@app.exception_handler(Exception)
async def _unexpected_handler(_: Request, __: Exception) -> JSONResponse:
    # Catch-all so unexpected errors never expose internals or stack traces.
    return _error(500, "Internal server error")


def _validate_city(city: str | None) -> str:
    if city is None or not city.strip():
        raise BadRequestError("Query parameter 'city' is required and must not be empty")
    return city.strip()


@app.get("/api/health", tags=["system"])
async def health() -> dict[str, str]:
    """Liveness probe for containers and deployment checks."""
    return {"status": "ok"}


@app.get("/api/locations", response_model=LocationsResponse, tags=["weather"])
async def locations(
    city: str | None = Query(default=None, description="City name to resolve"),
) -> LocationsResponse:
    """Return candidate locations for a city via Open-Meteo Geocoding."""
    return await get_locations(_validate_city(city))


@app.get("/api/weather", response_model=WeatherResponse, tags=["weather"])
async def weather(
    city: str | None = Query(default=None, description="City name to forecast"),
) -> WeatherResponse:
    """Return a normalized multi-day forecast for a city."""
    return await get_weather(_validate_city(city))


# Serve the minimal single-page frontend at "/" (optional, no build step).
# Served via an explicit route so unknown /api/* paths still return JSON errors.
_index_file = Path(__file__).parent / "static" / "index.html"


@app.get("/", include_in_schema=False)
async def index() -> FileResponse:
    return FileResponse(_index_file)
