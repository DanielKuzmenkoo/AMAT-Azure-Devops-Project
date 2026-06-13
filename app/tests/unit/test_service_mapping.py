"""Unit tests for the normalization helpers in src.service.

These exercise pure functions directly (no HTTP, no app), keeping them fast and
isolated. The full-stack behaviour is covered by the integration suite.
"""
from __future__ import annotations

from src.service import _daily_humidity_means, _map_forecast, _to_location


def test_to_location_uses_defaults_for_optional_fields() -> None:
    loc = _to_location({"latitude": 1.0, "longitude": 2.0})
    assert loc.name == ""
    assert loc.country is None
    assert loc.timezone is None
    assert (loc.latitude, loc.longitude) == (1.0, 2.0)


def test_daily_humidity_means_averages_per_day_and_rounds() -> None:
    hourly = {
        "time": ["2026-06-12T00:00", "2026-06-12T01:00", "2026-06-13T00:00"],
        "relative_humidity_2m": [60, 70, 81],
    }
    means = _daily_humidity_means(hourly)
    assert means == {"2026-06-12": 65.0, "2026-06-13": 81.0}


def test_daily_humidity_means_skips_none_and_empty() -> None:
    hourly = {
        "time": ["2026-06-12T00:00", "2026-06-12T01:00"],
        "relative_humidity_2m": [None, 80],
    }
    assert _daily_humidity_means(hourly) == {"2026-06-12": 80.0}
    # Missing hourly block must not raise.
    assert _daily_humidity_means({}) == {}


def test_map_forecast_joins_humidity_and_describes_codes() -> None:
    location = _to_location({"name": "Berlin", "latitude": 52.52, "longitude": 13.41})
    payload = {
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
    result = _map_forecast(location, payload)
    assert result.forecast_days == 2

    first = result.forecast[0]
    assert first.condition == "Mainly clear"
    assert first.humidity_pct == 65.0
    assert (first.temperature_max_c, first.temperature_min_c) == (20.0, 10.0)

    second = result.forecast[1]
    assert second.condition == "Slight rain"
    assert second.humidity_pct == 80.0


def test_map_forecast_tolerates_missing_columns() -> None:
    # Only dates present: other columns default to None rather than raising.
    location = _to_location({"name": "X", "latitude": 0.0, "longitude": 0.0})
    payload = {"daily": {"time": ["2026-06-12"]}, "hourly": {}}
    result = _map_forecast(location, payload)
    day = result.forecast[0]
    assert day.weather_code is None
    assert day.condition == "Unknown"
    assert day.temperature_max_c is None
    assert day.humidity_pct is None
