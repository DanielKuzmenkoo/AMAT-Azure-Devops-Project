"""Shared test fixtures, sample Open-Meteo payloads, and marker wiring.

Tests are organised by directory and auto-marked by ``pytest_collection_modifyitems``:

    tests/unit/         -> @pytest.mark.unit         fast, isolated, no I/O
    tests/integration/  -> @pytest.mark.integration  full app via TestClient + respx
    tests/e2e/          -> @pytest.mark.e2e          live, against a deployed BASE_URL
    tests/smoke/        -> @pytest.mark.smoke        live, minimal post-deploy checks

A bare ``pytest`` runs unit + integration only (see ``addopts`` in pyproject.toml);
e2e/smoke are opt-in with ``-m e2e`` / ``-m smoke`` and additionally skip when
BASE_URL is unset, so they never hit the network by accident.
"""
from __future__ import annotations

import os

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

_MARKER_DIRS = ("unit", "integration", "e2e", "smoke")


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    """Auto-apply a marker to each test based on its tests/<layer>/ directory."""
    for item in items:
        path = item.fspath.strpath.replace(os.sep, "/")
        for marker in _MARKER_DIRS:
            if f"/tests/{marker}/" in path:
                item.add_marker(getattr(pytest.mark, marker))
                break


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture(scope="session")
def base_url() -> str:
    """Base URL of a deployed app for live (e2e/smoke) tests.

    Skips the test when BASE_URL is not provided, so live suites are inert in
    local runs and in the build stage. The pipeline sets BASE_URL to the
    freshly deployed environment's URL.
    """
    url = os.getenv("BASE_URL")
    if not url:
        pytest.skip("BASE_URL not set; live test skipped")
    return url.rstrip("/")
