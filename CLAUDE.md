# Weather Azure DevOps Demo

This is an interview-focused DevOps project.

## Goals

* Build a small weather app.
* Demonstrate Azure DevOps CI/CD from a GitHub repo.
* Use Docker.
* Run lint/tests in CI.
* Deploy through dev and prod stages.
* Keep the design simple and explainable.

## Do Not Over-Engineer

* No unnecessary microservices.
* No service mesh.
* No complex Kubernetes unless explicitly requested.
* Prefer one clean pipeline over many pipelines.
* Prefer clear docs over clever abstractions.
* Avoid paid APIs or API keys unless explicitly requested.
* Do not introduce unnecessary infrastructure just to make the project look bigger.

## Quality Bar

* App must run locally.
* Tests must pass.
* Docker image must build.
* Pipeline YAML must be readable.
* README must explain architecture and CI/CD flow.
* Backend must handle missing city, unknown city, and upstream API errors.
* Frontend must show loading, empty state, success state, and error state if implemented.
* External API calls should be testable and mocked in unit tests.

---

# Weather API Design

The app should use a simple two-step weather flow:

1. User enters a city name.
2. Backend calls Open-Meteo Geocoding API to resolve city to coordinates.
3. Backend calls Open-Meteo Forecast API using latitude and longitude.
4. Backend returns a normalized forecast response to the frontend.

## Preferred APIs

* Geocoding: Open-Meteo Geocoding API
* Weather forecast: Open-Meteo Forecast API

## Reason

* No API key required.
* Good for an interview demo.
* Supports city lookup, coordinates, forecast days, humidity, precipitation, wind, and temperature.
* Keeps secret management simple.
* Makes local development and CI easier because no secret is required.

## API Rules

* Do not call external APIs directly from the frontend.
* The frontend should call the backend only.
* The backend should normalize third-party API responses before returning them to the frontend.
* Avoid exposing raw Open-Meteo response structures directly.
* Avoid introducing paid APIs or API keys unless explicitly requested.

## Backend API Contract

The backend should expose:

```text
GET /api/health
GET /api/locations?city=<city>
GET /api/weather?city=<city>
```

Expected behavior:

* `/api/health`

  * Returns service health.
  * Should be useful for container and deployment checks.

* `/api/locations?city=<city>`

  * Accepts a city name.
  * Calls Open-Meteo Geocoding API.
  * Returns possible matching locations.
  * Should include city name, country, latitude, longitude, and timezone where available.

* `/api/weather?city=<city>`

  * Accepts a city name.
  * Resolves the city to coordinates.
  * Calls Open-Meteo Forecast API.
  * Returns a normalized weather forecast.
  * Should include 7 to 14 days of weather data.
  * Should include temperature, humidity, precipitation probability, wind speed, and weather condition/code where available.

## Backend Error Handling

The backend should handle:

* Missing city query parameter.
* Empty city input.
* Unknown city / no geocoding results.
* External API timeout.
* External API unavailable.
* Unexpected upstream response format.

Do not leak stack traces or internal implementation details to the user.

Use clear HTTP status codes and simple error messages.

## Configuration

Use environment variables for configurable values:

```text
FORECAST_DAYS=14
GEOCODING_API_BASE_URL=https://geocoding-api.open-meteo.com/v1
WEATHER_API_BASE_URL=https://api.open-meteo.com/v1
HTTP_TIMEOUT_SECONDS=5
```

Open-Meteo does not require an API key, so no weather API secret is needed by default.

---

# GitFlow Strategy

This project uses a simple GitFlow model with the following branches:

## Main Branches

### `main`

* Represents production-ready code.
* Only stable, released versions should be merged here.
* Deployments to production should happen only from this branch.
* Every production release should be tagged, for example: `v1.0.0`.

### `develop`

* Main integration branch for ongoing development.
* Feature branches are merged into `develop`.
* CI should run lint, tests, and Docker build validation on this branch.
* Deployments to the dev environment should happen from this branch.

### `release/*`

* Used to prepare a production release.
* Created from `develop` when a version is ready for stabilization.
* Only bug fixes, documentation updates, and release-related changes should be added here.
* After validation, merge into both `main` and `develop`.

## Supporting Branches

### `feature/*`

* Used for new features or improvements.
* Created from `develop`.
* Merged back into `develop` using a pull request.
* Example: `feature/weather-api-client`.

### `hotfix/*`

* Used for urgent production fixes.
* Created from `main`.
* Merged back into both `main` and `develop`.
* Should trigger production validation and deployment after approval.
* Example: `hotfix/fix-health-endpoint`.

## GitFlow Rules

* Do not commit directly to `main`.
* Do not commit directly to `develop`.
* Use pull requests for all merges.
* Require successful CI before merging pull requests.
* Keep feature branches small and focused.
* Delete feature branches after merge.
* Use semantic versioning for releases:

  * `v1.0.0`
  * `v1.1.0`
  * `v1.1.1`

## Branch Flow

Feature development:

```text
develop
  └── feature/*
        └── pull request back to develop
```

Release flow:

```text
develop
  └── release/v1.0.0
        ├── merge to main
        └── merge back to develop
```

Hotfix flow:

```text
main
  └── hotfix/fix-critical-bug
        ├── merge to main
        └── merge back to develop
```

---

# Azure DevOps Pipeline Behavior

The Azure DevOps pipeline should follow this behavior:

## Pull Requests into `develop`

* Run lint.
* Run tests.
* Validate Docker build.

## Pushes to `develop`

* Run lint.
* Run tests.
* Build Docker image.
* Deploy to dev environment.

## Pushes to `release/*`

* Run lint.
* Run tests.
* Build Docker image.
* Deploy to staging or release validation environment if configured.

## Pushes to `main`

* Run lint.
* Run tests.
* Build Docker image.
* Push production image tag.
* Deploy to production after manual approval.

## Pushes to `hotfix/*`

* Run lint.
* Run tests.
* Build Docker image.
* Prepare urgent production fix validation.

## Image Tagging

Build the image once and push it to the shared ACR. The environment-facing tag
is derived from the branch at runtime (computed in the `BuildPush` stage and
passed to the deploy stages as an output variable). Never deploy `latest`.

| Branch | Image tag | Deploys to |
| --- | --- | --- |
| `develop` | `develop.<BuildId>` | dev |
| `release/*` | `release-<branch suffix>` (e.g. `release/v1.1.0` → `release-v1.1.0`) | staging |
| `main` | `prod-<VER>` — latest semver git tag with the **MINOR** bumped (e.g. `v1.1.0` → `prod-1.2.0`) | prod |
| `hotfix/*` | `prod-<VER>` — latest semver git tag with the **PATCH** bumped (e.g. `v1.1.0` → `prod-1.1.1`) | prod |
| `feature/*` / PR | `feature.<BuildId>` | validation only — **not pushed** |

Tagging rules:

* The immutable commit SHA is also pushed on every non-PR build, so every
  deployment has a fully traceable reference even when the branch tag is more
  human-readable.
* For `main` and `hotfix/*`, the build also creates and pushes an annotated git
  tag `v<VER>` to GitHub, so production releases are versioned in source
  control. This means CI owns prod versioning — do not also tag manually.
* The git tag push uses a secret `GITHUB_PAT` pipeline variable; never hardcode
  it. Pushing a tag does not retrigger CI (triggers are branch-based, not tags).
* `feature/*` images are built and validated locally / in PR checks but never
  pushed to the registry.

## Pipeline Rules

* Prefer one clear Azure Pipelines YAML file.
* Use Microsoft-hosted agents unless explicitly requested otherwise.
* Prefer:

```yaml
pool:
  vmImage: ubuntu-latest
```

* Do not add unnecessary agent demands.
* Do not require self-hosted agents for the basic demo.
* Keep branch conditions readable.
* Keep deployment stages easy to explain.
* Store secrets in Azure DevOps variables, variable groups, service connections, or Azure Key Vault only when secrets are actually needed.
* Since Open-Meteo does not require an API key, do not create unnecessary API-key secrets.

---

# Suggested Repository Structure

```text
weather-azure-devops/
├── CLAUDE.md
├── README.md
├── azure-pipelines.yml
├── app/
│   ├── src/
│   ├── tests/
│   └── Dockerfile
├── infra/
│   ├── bicep/ or terraform/
│   └── README.md
├── docs/
│   ├── architecture.md
│   ├── runbook.md
│   └── interview-notes.md
└── .claude/
    └── agents/
        ├── frontend-agent.md
        ├── backend-agent.md
        ├── pipeline-agent.md
        ├── infra-agent.md
        └── reviewer-agent.md
```

---

# Agent Workflow

Claude main chat acts as the planner and technical lead.

Use specialized agents only when their domain is relevant:

* Use `frontend-agent` for frontend UI, API calls, loading states, errors, and browser behavior.
* Use `backend-agent` for API routes, Open-Meteo geocoding, Open-Meteo forecast integration, tests, and backend structure.
* Use `pipeline-agent` for Azure DevOps YAML, GitFlow triggers, Docker build, CI checks, and deployment stages.
* Use `infra-agent` for Terraform/Bicep/Azure resource definitions.
* Use `reviewer-agent` before major commits or before the interview to check the whole project.

Do not use all agents for every task.

Default flow:

1. Understand the requested change.
2. Decide which area is affected.
3. Use one specialist agent if needed.
4. Make the smallest practical change.
5. Run or suggest validation.
6. Update docs if behavior changed.

Avoid agent spam. Prefer one focused agent per task.

---

# Interview Focus

When explaining this project, emphasize:

* The project is intentionally small so the DevOps flow is easy to understand.
* `develop` is used for active integration.
* `feature/*` branches keep changes isolated.
* `release/*` branches allow stabilization before production.
* `main` always represents production-ready code.
* `hotfix/*` branches allow urgent fixes without waiting for normal development flow.
* Azure DevOps enforces quality gates through linting, testing, Docker build validation, and environment approvals.
* The backend hides third-party API details from the frontend.
* The app uses Open-Meteo to avoid unnecessary secret management in an interview demo.
* Docker makes the app portable between local development, CI, and cloud deployment.
* The design shows release discipline without adding unnecessary complexity.

The GitFlow and architecture are intentionally simple and practical for a demo project. They show professional engineering habits without over-engineering.
