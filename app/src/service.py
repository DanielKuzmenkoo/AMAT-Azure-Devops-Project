"""Orchestration: resolve a city, fetch its forecast, and normalize the result."""
from __future__ import annotations

from collections import defaultdict
from typing import Any

from . import open_meteo
from .schemas import DailyForecast, Location, LocationsResponse, WeatherResponse
from .weather_codes import describe_weather_code


class CityNotFoundError(Exception):
    """Raised when geocoding returns no matches for a city."""


def _to_location(raw: dict[str, Any]) -> Location:
    return Location(
        name=raw.get("name", ""),
        country=raw.get("country"),
        latitude=raw["latitude"],
        longitude=raw["longitude"],
        timezone=raw.get("timezone"),
    )


async def get_locations(city: str) -> LocationsResponse:
    """Return candidate locations matching a city name."""
    results = await open_meteo.geocode_city(city)
    return LocationsResponse(city=city, results=[_to_location(r) for r in results])


def _daily_humidity_means(hourly: dict[str, Any]) -> dict[str, float]:
    """Average hourly relative humidity into a per-day mean keyed by date (YYYY-MM-DD)."""
    times = hourly.get("time") or []
    values = hourly.get("relative_humidity_2m") or []
    buckets: dict[str, list[float]] = defaultdict(list)
    for timestamp, value in zip(times, values, strict=False):
        if value is None:
            continue
        buckets[timestamp[:10]].append(value)
    return {day: round(sum(v) / len(v), 1) for day, v in buckets.items() if v}


def _map_forecast(location: Location, payload: dict[str, Any]) -> WeatherResponse:
    daily = payload.get("daily") or {}
    dates = daily.get("time") or []
    humidity_by_day = _daily_humidity_means(payload.get("hourly") or {})

    def column(key: str) -> list[Any]:
        return daily.get(key) or [None] * len(dates)

    codes = column("weather_code")
    temp_max = column("temperature_2m_max")
    temp_min = column("temperature_2m_min")
    precip = column("precipitation_probability_max")
    wind = column("wind_speed_10m_max")

    forecast = [
        DailyForecast(
            date=date,
            weather_code=codes[i],
            condition=describe_weather_code(codes[i]),
            temperature_max_c=temp_max[i],
            temperature_min_c=temp_min[i],
            humidity_pct=humidity_by_day.get(date),
            precipitation_probability_pct=precip[i],
            wind_speed_max_kmh=wind[i],
        )
        for i, date in enumerate(dates)
    ]
    return WeatherResponse(location=location, forecast_days=len(forecast), forecast=forecast)


async def get_weather(city: str) -> WeatherResponse:
    """Resolve a city to its best match and return a normalized forecast."""
    results = await open_meteo.geocode_city(city)
    if not results:
        raise CityNotFoundError(f"No location found for city '{city}'")

    location = _to_location(results[0])
    payload = await open_meteo.fetch_forecast(
        location.latitude, location.longitude, location.timezone
    )
    return _map_forecast(location, payload)
