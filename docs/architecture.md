# Architecture

## Overview

A small FastAPI weather API, containerized once and deployed to one of two
targets per environment:

1. **Azure Container Apps (ACA)** — the managed, serverless container runtime
   (the "ECS-equivalent"). Preferred cloud path.
2. **Azure VM + Docker, configured by Ansible** — simulates an on-prem /
   VM-style deployment of the *same* image.

```text
                         ┌──────────────────────────────┐
   Browser ──▶ Frontend ─┤  Weather API (FastAPI)        │
   (city)    (static)    │  /api/health                  │
                         │  /api/locations?city=...      │
                         │  /api/weather?city=...        │
                         └──────────────┬────────────────┘
                                        │ server-side only
                         ┌──────────────┴───────────────┐
                         ▼                               ▼
              Open-Meteo Geocoding API        Open-Meteo Forecast API
              (city → lat/lon/tz)             (forecast by coordinates)

   Build & promote one image:

   Dockerfile ─▶ Azure Container Registry (shared) ─┬─▶ ACA (dev/staging/prod)
                                                    └─▶ VM + Docker (Ansible)
```

## Components

| Layer | Tech | Notes |
|---|---|---|
| App | Python FastAPI | `app/src`, port 8000, `/api/health` for probes |
| Image | Docker | One image, non-root, healthcheck |
| Registry | Azure Container Registry | **Shared** across environments |
| Cloud runtime | Azure Container Apps | HTTPS ingress, scaling, managed identity pull |
| On-prem sim | Azure Linux VM + Docker | Provisioned by Terraform, configured by Ansible |
| IaC | Terraform modules + Terragrunt | dev / staging / prod, DRY |
| CI/CD | Azure DevOps | one pipeline, build once, deploy chosen target |

## Why these choices

- **Azure Container Apps** gives a managed container runtime with HTTPS, scale-
  to-zero, revisions, and health probes — without running or patching
  Kubernetes. It is the closest Azure analogue to AWS ECS/Fargate for a demo.
- **Shared ACR** so an image is **built once and promoted** across dev →
  staging → prod by tag. No per-environment rebuild means what you tested is
  exactly what ships.
- **VM + Ansible** proves the artifact is portable: the same image runs on a
  plain Docker host, demonstrating on-prem compatibility without changing the
  app.
- **Managed identity (AcrPull)** for ACA so there are no registry credentials
  stored anywhere. The VM path uses a short-lived ACR token at deploy time.

## Configuration (non-secret)

The app is configured purely with environment variables — Open-Meteo needs no
API key:

`FORECAST_DAYS`, `GEOCODING_API_BASE_URL`, `WEATHER_API_BASE_URL`,
`HTTP_TIMEOUT_SECONDS`.

## Intentionally NOT included

AKS / Kubernetes, service mesh, a database, and Key Vault. There is no secret to
store (no API key) and no state to persist, so adding them would be
over-engineering for an interview demo. See [deployment.md](deployment.md) and
[onprem-simulation.md](onprem-simulation.md) for the how-to.
