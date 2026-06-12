"""Normalized response models returned to clients.

These deliberately hide the raw Open-Meteo response shape so the frontend
depends only on our stable contract.
"""
from __future__ import annotations

from pydantic import BaseModel


class Location(BaseModel):
    name: str
    country: str | None = None
    latitude: float
    longitude: float
    timezone: str | None = None


class LocationsResponse(BaseModel):
    city: str
    results: list[Location]


class DailyForecast(BaseModel):
    date: str
    weather_code: int | None = None
    condition: str
    temperature_max_c: float | None = None
    temperature_min_c: float | None = None
    humidity_pct: float | None = None
    precipitation_probability_pct: float | None = None
    wind_speed_max_kmh: float | None = None


class WeatherResponse(BaseModel):
    location: Location
    forecast_days: int
    forecast: list[DailyForecast]


class ErrorResponse(BaseModel):
    error: str
