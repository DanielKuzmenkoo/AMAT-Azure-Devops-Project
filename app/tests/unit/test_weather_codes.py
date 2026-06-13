"""Unit tests for WMO weather-code mapping."""
from __future__ import annotations

from src.weather_codes import describe_weather_code


def test_known_code_maps_to_condition() -> None:
    assert describe_weather_code(0) == "Clear sky"
    assert describe_weather_code(61) == "Slight rain"
    assert describe_weather_code(95) == "Thunderstorm"


def test_none_code_is_unknown() -> None:
    assert describe_weather_code(None) == "Unknown"


def test_unmapped_code_is_unknown() -> None:
    # 7 is not a defined WMO code in our table.
    assert describe_weather_code(7) == "Unknown"
