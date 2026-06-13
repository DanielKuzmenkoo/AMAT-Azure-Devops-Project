"""End-to-end tests against a deployed environment with REAL Open-Meteo calls.

Run against a live URL (the pipeline points BASE_URL at the freshly deployed
staging app):

    BASE_URL=https://ca-weather-staging.<...>.azurecontainerapps.io \
        pytest -m e2e

Skipped automatically when BASE_URL is unset. These exercise the full stack and
the real upstream APIs, so they are heavier than the mocked integration suite
and run only on the release branch before promoting to production.
"""
from __future__ import annotations

import httpx
import pytest

TIMEOUT = 20.0


@pytest.fixture(scope="session")
def http(base_url: str) -> httpx.Client:
    with httpx.Client(base_url=base_url, timeout=TIMEOUT) as client:
        yield client


def test_health(http: httpx.Client) -> None:
    resp = http.get("/api/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_weather_real_city_returns_forecast(http: httpx.Client) -> None:
    resp = http.get("/api/weather", params={"city": "London"})
    assert resp.status_code == 200
    body = resp.json()

    assert body["location"]["name"]
    assert body["forecast_days"] >= 1
    assert len(body["forecast"]) == body["forecast_days"]

    day = body["forecast"][0]
    for key in (
        "date",
        "weather_code",
        "condition",
        "temperature_max_c",
        "temperature_min_c",
        "humidity_pct",
        "precipitation_probability_pct",
        "wind_speed_max_kmh",
    ):
        assert key in day


def test_locations_real_city(http: httpx.Client) -> None:
    resp = http.get("/api/locations", params={"city": "London"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["city"] == "London"
    assert any(r["name"] for r in body["results"])


def test_unknown_city_returns_404(http: httpx.Client) -> None:
    resp = http.get("/api/weather", params={"city": "Zzzxqwerty Nowhereville"})
    assert resp.status_code == 404
    assert "error" in resp.json()


def test_missing_city_returns_400(http: httpx.Client) -> None:
    resp = http.get("/api/weather")
    assert resp.status_code == 400
    assert "error" in resp.json()
