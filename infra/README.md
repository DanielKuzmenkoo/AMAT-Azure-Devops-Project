# Infrastructure

Intentionally omitted for this demo.

The app is a single stateless container with no database and no secrets
(Open-Meteo needs no API key), so there is nothing to provision for it to run
locally or in CI.

If this were taken to a real environment, this directory would hold the IaC
(Bicep or Terraform) for, e.g.:

- An Azure Container Registry to host the image.
- An Azure App Service (containers) or Container Apps environment to run it.
- The Azure DevOps service connection wiring used by the deploy stages in
  [../azure-pipelines.yml](../azure-pipelines.yml).

Keeping it empty here is a deliberate choice to avoid over-engineering an
interview demo — see the "Over-engineering" notes in [../README.md](../README.md).
