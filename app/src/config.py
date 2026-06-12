"""Application configuration sourced from environment variables.

Open-Meteo requires no API key, so there are no secrets here. Defaults are
suitable for local development and CI.
"""
from __future__ import annotations

import os


class Settings:
    """Runtime configuration read once at import time."""

    def __init__(self) -> None:
        self.forecast_days: int = int(os.getenv("FORECAST_DAYS", "14"))
        self.geocoding_api_base_url: str = os.getenv(
            "GEOCODING_API_BASE_URL", "https://geocoding-api.open-meteo.com/v1"
        ).rstrip("/")
        self.weather_api_base_url: str = os.getenv(
            "WEATHER_API_BASE_URL", "https://api.open-meteo.com/v1"
        ).rstrip("/")
        self.http_timeout_seconds: float = float(os.getenv("HTTP_TIMEOUT_SECONDS", "5"))

        # Open-Meteo accepts 1..16 forecast days; clamp to the contract's 7..14.
        self.forecast_days = max(7, min(self.forecast_days, 14))


settings = Settings()
