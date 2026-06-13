"""Tests for the locations and weather endpoints with mocked Open-Meteo calls."""
from __future__ import annotations

import httpx
import respx
from fastapi.testclient import TestClient

from tests.conftest import FORECAST_RESPONSE, FORECAST_URL, GEOCODING_RESPONSE, GEOCODING_URL


def test_weather_missing_city(client: TestClient) -> None:
    response = client.get("/api/weather")
    assert response.status_code == 400
    assert "error" in response.json()


def test_weather_empty_city(client: TestClient) -> None:
    response = client.get("/api/weather", params={"city": "   "})
    assert response.status_code == 400
    assert "error" in response.json()


@respx.mock
def test_weather_city_not_found(client: TestClient) -> None:
    respx.get(GEOCODING_URL).mock(return_value=httpx.Response(200, json={"results": []}))

    response = client.get("/api/weather", params={"city": "Nowhereville"})
    assert response.status_code == 404
    assert "error" in response.json()


@respx.mock
def test_weather_success_mapping(client: TestClient) -> None:
    respx.get(GEOCODING_URL).mock(return_value=httpx.Response(200, json=GEOCODING_RESPONSE))
    respx.get(FORECAST_URL).mock(return_value=httpx.Response(200, json=FORECAST_RESPONSE))

    response = client.get("/api/weather", params={"city": "Berlin"})
    assert response.status_code == 200
    body = response.json()

    assert body["location"] == {
        "name": "Berlin",
        "country": "Germany",
        "latitude": 52.52,
        "longitude": 13.41,
        "timezone": "Europe/Berlin",
    }
    assert body["forecast_days"] == 2

    day_one = body["forecast"][0]
    assert day_one["date"] == "2026-06-12"
    assert day_one["weather_code"] == 1
    assert day_one["condition"] == "Mainly clear"
    assert day_one["temperature_max_c"] == 20.0
    assert day_one["temperature_min_c"] == 10.0
    assert day_one["precipitation_probability_pct"] == 10
    assert day_one["wind_speed_max_kmh"] == 15.0
    # Humidity is averaged from the two hourly samples on 2026-06-12: (60 + 70) / 2.
    assert day_one["humidity_pct"] == 65.0

    day_two = body["forecast"][1]
    assert day_two["condition"] == "Slight rain"
    assert day_two["humidity_pct"] == 80.0


@respx.mock
def test_weather_unknown_weather_code(client: TestClient) -> None:
    forecast = {
        "daily": {
            "time": ["2026-06-12"],
            "weather_code": [None],
            "temperature_2m_max": [20.0],
            "temperature_2m_min": [10.0],
            "precipitation_probability_max": [10],
            "wind_speed_10m_max": [15.0],
        },
        "hourly": {"time": [], "relative_humidity_2m": []},
    }
    respx.get(GEOCODING_URL).mock(return_value=httpx.Response(200, json=GEOCODING_RESPONSE))
    respx.get(FORECAST_URL).mock(return_value=httpx.Response(200, json=forecast))

    response = client.get("/api/weather", params={"city": "Berlin"})
    assert response.status_code == 200
    day = response.json()["forecast"][0]
    assert day["weather_code"] is None
    assert day["condition"] == "Unknown"
    # No hourly samples -> humidity is null rather than an error.
    assert day["humidity_pct"] is None


@respx.mock
def test_weather_geocoding_failure(client: TestClient) -> None:
    respx.get(GEOCODING_URL).mock(return_value=httpx.Response(500))

    response = client.get("/api/weather", params={"city": "Berlin"})
    assert response.status_code == 502
    assert "error" in response.json()


@respx.mock
def test_weather_forecast_failure(client: TestClient) -> None:
    # Geocoding succeeds but the forecast call fails -> still a clean 502.
    respx.get(GEOCODING_URL).mock(return_value=httpx.Response(200, json=GEOCODING_RESPONSE))
    respx.get(FORECAST_URL).mock(return_value=httpx.Response(503))

    response = client.get("/api/weather", params={"city": "Berlin"})
    assert response.status_code == 502
    assert "error" in response.json()


@respx.mock
def test_weather_upstream_timeout(client: TestClient) -> None:
    respx.get(GEOCODING_URL).mock(side_effect=httpx.ConnectTimeout("timed out"))

    response = client.get("/api/weather", params={"city": "Berlin"})
    assert response.status_code == 504
    assert "error" in response.json()


@respx.mock
def test_locations_success(client: TestClient) -> None:
    respx.get(GEOCODING_URL).mock(return_value=httpx.Response(200, json=GEOCODING_RESPONSE))

    response = client.get("/api/locations", params={"city": "Berlin"})
    assert response.status_code == 200
    body = response.json()
    assert body["city"] == "Berlin"
    assert body["results"][0]["name"] == "Berlin"
    assert body["results"][0]["timezone"] == "Europe/Berlin"


def test_locations_missing_city(client: TestClient) -> None:
    response = client.get("/api/locations")
    assert response.status_code == 400
    assert "error" in response.json()
