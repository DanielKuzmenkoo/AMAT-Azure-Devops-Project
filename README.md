# Weather Azure DevOps Demo

A small, interview-focused weather application that demonstrates a clean backend
API, Docker packaging, automated tests, and an Azure DevOps CI/CD pipeline built
around a GitFlow branching model.

The app is intentionally minimal. The point is not the weather — it's showing
professional DevOps habits (containerization, testing, quality gates, release
discipline) without over-engineering.

## Project purpose

- Resolve a city name to a multi-day weather forecast.
- Hide third-party API details behind a clean backend contract.
- Run lint, tests, and a Docker build as CI quality gates.
- Demonstrate GitFlow-driven deployments (dev / prod) in Azure DevOps.
- Use **Open-Meteo** (no API key) so there are no secrets to manage in a demo.

## Architecture

```text
            ┌──────────────┐        ┌─────────────────────────────┐
 Browser ──▶│  Frontend    │ ──────▶│        Backend (FastAPI)    │
 (city)     │ static HTML  │  /api  │  /api/health                │
            └──────────────┘        │  /api/locations?city=...    │
                                    │  /api/weather?city=...      │
                                    └───────────┬─────────────────┘
                                                │  (server-side only)
                            ┌───────────────────┴───────────────────┐
                            ▼                                        ▼
                 Open-Meteo Geocoding API                Open-Meteo Forecast API
                 (city → lat/lon/country/tz)             (forecast by coordinates)
```

- The frontend calls **only** the backend — never Open-Meteo directly.
- The backend resolves the city to coordinates, fetches the forecast, and
  returns a **normalized** response, so the frontend never sees raw upstream
  JSON.
- No database: the data is read-through from Open-Meteo and is not persisted.

### Layout

```text
app/
├── src/
│   ├── main.py          # FastAPI app, routes, exception handlers
│   ├── service.py       # orchestration + mapping to normalized schema
│   ├── open_meteo.py    # async HTTP client for the two Open-Meteo APIs
│   ├── schemas.py       # Pydantic response models (the public contract)
│   ├── config.py        # env-based configuration
│   ├── weather_codes.py # WMO code → human-readable condition
│   └── static/index.html# minimal frontend (loading/empty/success/error states)
├── tests/               # unit tests with mocked Open-Meteo calls
├── Dockerfile
├── requirements.txt     # runtime deps
└── requirements-dev.txt # test + lint deps
azure-pipelines.yml      # single CI/CD pipeline
CLAUDE.md                # project spec / design notes
```

## API contract

| Method & path | Description |
|---|---|
| `GET /api/health` | Liveness check. Returns `{"status": "ok"}`. |
| `GET /api/locations?city=<city>` | Candidate locations (name, country, lat, lon, timezone). |
| `GET /api/weather?city=<city>` | Normalized 7–14 day forecast for the best-matched city. |

Errors share a single shape: `{"error": "<message>"}`.

| Situation | Status |
|---|---|
| Missing / empty `city` | `400` |
| City not found (no geocoding match) | `404` |
| Upstream timeout | `504` |
| Upstream unavailable / bad response | `502` |
| Unexpected error | `500` (no stack traces leaked) |

### Examples

```bash
# Health
curl http://localhost:8000/api/health
# {"status":"ok"}

# Locations
curl "http://localhost:8000/api/locations?city=Berlin"

# Weather (normalized forecast)
curl "http://localhost:8000/api/weather?city=Berlin"
```

Example weather response (truncated):

```json
{
  "location": {
    "name": "Berlin", "country": "Germany",
    "latitude": 52.52, "longitude": 13.41, "timezone": "Europe/Berlin"
  },
  "forecast_days": 14,
  "forecast": [
    {
      "date": "2026-06-12",
      "weather_code": 80,
      "condition": "Slight rain showers",
      "temperature_max_c": 17.1,
      "temperature_min_c": 11.4,
      "humidity_pct": 71.5,
      "precipitation_probability_pct": 63.0,
      "wind_speed_max_kmh": 15.1
    }
  ]
}
```

## Configuration

All configuration is via environment variables (no secrets required):

| Variable | Default | Purpose |
|---|---|---|
| `FORECAST_DAYS` | `14` | Forecast length (clamped to 7–14). |
| `GEOCODING_API_BASE_URL` | `https://geocoding-api.open-meteo.com/v1` | Geocoding base URL. |
| `WEATHER_API_BASE_URL` | `https://api.open-meteo.com/v1` | Forecast base URL. |
| `HTTP_TIMEOUT_SECONDS` | `5` | Upstream HTTP timeout. |

## Run locally

Requires Python 3.12+.

```bash
cd app
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

# Start the API (serves the frontend at http://localhost:8000/)
uvicorn src.main:app --reload
```

Then open <http://localhost:8000/> for the UI, or call the API directly.

### Lint & test

```bash
cd app
ruff check src tests
pytest -q
```

## Run with Docker

```bash
cd app
docker build -t weather-api .
docker run --rm -p 8000:8000 weather-api
```

The image runs as a non-root user and includes a `HEALTHCHECK` that hits
`/api/health`. Open <http://localhost:8000/> once it is up.

## CI/CD flow (Azure DevOps)

A single, readable pipeline ([azure-pipelines.yml](azure-pipelines.yml)) on a
Microsoft-hosted agent (`ubuntu-latest`):

- **Validate** (runs on every PR and push to `main`, `develop`, `release/*`,
  `hotfix/*`): install deps → **lint** (ruff) → **tests** (pytest) → **Docker
  build validation**.
- **Deploy to dev**: runs only on pushes to `develop`.
- **Deploy to production**: runs only on pushes to `main`, gated by a manual
  approval on the `weather-prod` Azure DevOps environment.

PRs into `develop`/`main` run the Validate stage only — no deployment.

The deploy steps are placeholders (`echo`) so the pipeline is green without a
cloud subscription. Wire them to a service connection / container registry when
one is available.

## GitFlow

| Branch | Role |
|---|---|
| `main` | Production-ready. Tagged releases (`v1.0.0`). Deploys to prod (with approval). |
| `develop` | Active integration. Deploys to dev. |
| `feature/*` | New work, branched from `develop`, merged back via PR. |
| `release/*` | Stabilization before a release; merged to `main` and back to `develop`. |
| `hotfix/*` | Urgent production fixes from `main`, merged to `main` and `develop`. |

Rules: no direct commits to `main`/`develop`; all merges via PR; CI must pass
before merge; releases use semantic versioning.

```text
feature/* ──▶ develop ──▶ release/* ──▶ main
                  ▲                       │
                  └──────── hotfix/* ◀────┘
```

## Interview talking points

- **Small on purpose.** A tiny app keeps the focus on the DevOps flow, which is
  what the pipeline and branching model demonstrate.
- **Clean layering.** Routes → service → HTTP client → schemas. The client is
  the only thing that talks to Open-Meteo, which makes it trivial to mock in
  tests.
- **Contract isolation.** The backend normalizes upstream JSON, so the frontend
  depends on a stable shape, not on Open-Meteo's structure.
- **No secrets.** Open-Meteo needs no API key, so there's no secret management
  to distract from the demo — and CI/local dev stay identical.
- **Real quality gates.** Lint + tests + Docker build run on every PR; prod
  deploys require a manual approval — release discipline without complexity.
- **Honest scope.** No database, no Kubernetes, no microservices — added only
  if a real requirement justified them.
