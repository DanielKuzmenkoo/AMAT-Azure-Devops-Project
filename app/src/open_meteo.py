"""Thin async client for the Open-Meteo Geocoding and Forecast APIs.

The client only performs HTTP and raises typed errors. Mapping to our
normalized schema lives in ``service.py`` so this layer stays easy to mock.
"""
from __future__ import annotations

from typing import Any

import httpx

from .config import settings


class UpstreamTimeoutError(Exception):
    """Raised when an upstream Open-Meteo request times out."""


class UpstreamError(Exception):
    """Raised when an upstream Open-Meteo request fails or is unavailable."""


async def _get_json(url: str, params: dict[str, Any]) -> dict[str, Any]:
    """Perform a GET request and return parsed JSON, mapping failures to typed errors."""
    try:
        async with httpx.AsyncClient(timeout=settings.http_timeout_seconds) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            return response.json()
    except httpx.TimeoutException as exc:
        raise UpstreamTimeoutError("Weather provider timed out") from exc
    except (httpx.HTTPError, ValueError) as exc:
        # Covers connection errors, non-2xx responses, and invalid JSON.
        raise UpstreamError("Weather provider is unavailable") from exc


async def geocode_city(city: str) -> list[dict[str, Any]]:
    """Resolve a city name to candidate locations via the Geocoding API."""
    data = await _get_json(
        f"{settings.geocoding_api_base_url}/search",
        params={"name": city, "count": 5, "language": "en", "format": "json"},
    )
    return data.get("results") or []


async def fetch_forecast(latitude: float, longitude: float, timezone: str | None) -> dict[str, Any]:
    """Fetch a multi-day forecast for the given coordinates via the Forecast API."""
    params: dict[str, Any] = {
        "latitude": latitude,
        "longitude": longitude,
        "forecast_days": settings.forecast_days,
        "timezone": timezone or "auto",
        "daily": ",".join(
            [
                "weather_code",
                "temperature_2m_max",
                "temperature_2m_min",
                "precipitation_probability_max",
                "wind_speed_10m_max",
            ]
        ),
        "hourly": "relative_humidity_2m",
    }
    return await _get_json(f"{settings.weather_api_base_url}/forecast", params=params)
