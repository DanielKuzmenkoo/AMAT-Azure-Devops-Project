"""Shared test fixtures and sample Open-Meteo payloads."""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from src.main import app

GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search"
FORECAST_URL = "https://api.open-meteo.com/v1/forecast"

GEOCODING_RESPONSE = {
    "results": [
        {
            "name": "Berlin",
            "country": "Germany",
            "latitude": 52.52,
            "longitude": 13.41,
            "timezone": "Europe/Berlin",
        }
    ]
}

FORECAST_RESPONSE = {
    "daily": {
        "time": ["2026-06-12", "2026-06-13"],
        "weather_code": [1, 61],
        "temperature_2m_max": [20.0, 18.0],
        "temperature_2m_min": [10.0, 9.0],
        "precipitation_probability_max": [10, 80],
        "wind_speed_10m_max": [15.0, 22.0],
    },
    "hourly": {
        "time": ["2026-06-12T00:00", "2026-06-12T01:00", "2026-06-13T00:00"],
        "relative_humidity_2m": [60, 70, 80],
    },
}


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)
