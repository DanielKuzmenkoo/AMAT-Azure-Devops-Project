"""Post-deploy smoke tests against a deployed environment.

Minimal, fast, and non-destructive — safe to run against production right after
a deploy. Verifies the app is up (health) and that the core path is wired in the
environment (one real forecast lookup). The pipeline runs these against each
deployed environment:

    BASE_URL=https://<app-url> pytest -m smoke

Skipped automatically when BASE_URL is unset.
"""
from __future__ import annotations

import httpx
import pytest

TIMEOUT = 20.0


@pytest.fixture(scope="session")
def http(base_url: str) -> httpx.Client:
    with httpx.Client(base_url=base_url, timeout=TIMEOUT) as client:
        yield client


def test_health_ok(http: httpx.Client) -> None:
    resp = http.get("/api/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_core_weather_path_works(http: httpx.Client) -> None:
    resp = http.get("/api/weather", params={"city": "London"})
    assert resp.status_code == 200
    assert resp.json()["forecast_days"] >= 1
