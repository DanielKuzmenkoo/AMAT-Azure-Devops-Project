"""Unit tests for environment-driven Settings."""
from __future__ import annotations

import pytest

from src.config import Settings


def test_defaults_when_env_absent(monkeypatch: pytest.MonkeyPatch) -> None:
    for var in (
        "FORECAST_DAYS",
        "GEOCODING_API_BASE_URL",
        "WEATHER_API_BASE_URL",
        "HTTP_TIMEOUT_SECONDS",
    ):
        monkeypatch.delenv(var, raising=False)
    s = Settings()
    assert s.forecast_days == 14
    assert s.geocoding_api_base_url == "https://geocoding-api.open-meteo.com/v1"
    assert s.weather_api_base_url == "https://api.open-meteo.com/v1"
    assert s.http_timeout_seconds == 5.0


@pytest.mark.parametrize(
    ("raw", "expected"),
    [("1", 7), ("7", 7), ("10", 10), ("14", 14), ("30", 14)],
)
def test_forecast_days_clamped_to_contract(
    monkeypatch: pytest.MonkeyPatch, raw: str, expected: int
) -> None:
    monkeypatch.setenv("FORECAST_DAYS", raw)
    assert Settings().forecast_days == expected


def test_base_urls_strip_trailing_slash(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GEOCODING_API_BASE_URL", "https://example.com/geo/")
    monkeypatch.setenv("WEATHER_API_BASE_URL", "https://example.com/wx/")
    s = Settings()
    assert s.geocoding_api_base_url == "https://example.com/geo"
    assert s.weather_api_base_url == "https://example.com/wx"
