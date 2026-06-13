# Observability

Monitoring is **Azure-native and serverless** — no VMs and no self-hosted stack
to run. The app and the pipeline both report to **Application Insights**, which
is backed by the **same Log Analytics workspace** the Container Apps environment
already uses.

```text
FastAPI app (dev/staging/prod)
   │  OpenTelemetry (requests, latency, failures, exceptions,
   │  Open-Meteo httpx dependency calls)
   ▼
Application Insights ───backed by──▶ Log Analytics workspace (shared, in the CAE)
   ▲                                     ▲
   │  deployment events (DORA)           │  Container Apps platform logs & metrics
Azure DevOps pipeline ──────────────────┘
```

Why not a Prometheus/Grafana/Loki stack on a VM? For a serverless app it would
add a 24/7 VM to patch and secure, awkward scraping of a dynamic ingress, and
custom glue to pull Azure DevOps data in — all to monitor something smaller than
the monitoring itself. App Insights gives traces, metrics, logs, a service map,
and alerting with no infrastructure to run. (If a Grafana pane is ever required,
the right move is Azure Managed Grafana on the Azure Monitor data source — still
no VM.)

## What is collected

### Application (Azure Container Apps)

Instrumented with the **Azure Monitor OpenTelemetry distro**
(`azure-monitor-opentelemetry`, see [app/src/main.py](../app/src/main.py)):

- **Requests** — rate, latency (p50/p95/p99), and failure rate per endpoint
  (`/api/health`, `/api/locations`, `/api/weather`).
- **Dependencies** — the outbound **Open-Meteo** geocoding and forecast calls
  (httpx), with duration and success — so you can see when upstream is slow.
- **Exceptions** — server-side errors, correlated to the failing request.
- **Logs & platform metrics** — Container Apps already streams stdout logs and
  system metrics (CPU, memory, replicas, request volume) into the workspace.

Instrumentation is **guarded by `APPLICATIONINSIGHTS_CONNECTION_STRING`**. When
it is unset — local development, CI, and tests — the app emits no telemetry and
the OpenTelemetry packages are never exercised, so behavior is unchanged.

One Application Insights serves all environments; they are separated by
**OpenTelemetry cloud role name** (`OTEL_SERVICE_NAME = weather-<env>`), so the
Application Map and queries can filter by `cloud_RoleName` = `weather-dev` /
`weather-staging` / `weather-prod`.

### CI/CD pipeline

Each deploy posts a **deployment event** to Application Insights (see the
"Record deployment event (DORA)" step in
[.azure/deploy-aca.yml](../.azure/deploy-aca.yml)). It runs on **success and
failure**, with properties: `environment`, `imageTag`, `commit`, `pipeline`,
`result`. From these you get **DORA-style metrics**:

- **Deployment frequency** — count of `Deployment` events per env over time.
- **Lead time** — commit timestamp → deployment event time.
- **Change-failure rate** — `result = Failed` over total deployments.

This complements Azure DevOps' built-in **pipeline Analytics** (build pass rate,
duration trends) and the deploy stage's `/api/health` check.

The Validate stage also publishes **test results** (JUnit) and **code coverage**
(Cobertura) via `PublishTestResults@2` / `PublishCodeCoverageResults@2`, so
per-build test pass rate, trends, and flaky-test detection light up natively.

### Where to watch the pipeline

| Signal | Where |
|---|---|
| Build pass rate, duration trends | Azure DevOps → **Pipelines → <pipeline> → Analytics** |
| Test pass rate / trends / flaky tests | the run's **Tests** tab, and Pipelines → Analytics (test report) |
| Code coverage per build | the run's **Code Coverage** tab |
| Deployment frequency, lead time, change-failure rate (DORA) | App Insights → **Logs** (`customEvents` query below) or the **Workbook** |
| Live deploy URL + health per run | the run's **Summary** tab (published by the deploy job) |

Build/run logs and metrics live **inside Azure DevOps** by design (Analytics +
Dashboards); only deployment events are forwarded to App Insights for DORA. We
deliberately do not ship raw pipeline logs into Azure Monitor.

To pin pipeline tiles to a board: Azure DevOps → **Overview → Dashboards → New
Dashboard**, then add widgets — *Build history*, *Test results trend*,
*Deployment status*, *Code coverage*.

## Setup

Provisioned by [scripts/bootstrap-infra.sh](../scripts/bootstrap-infra.sh)
(step `[4/5]`, the `shared/monitoring` unit). The app picks up the connection
string automatically — the `container-app` module injects it as an env var from
the monitoring unit's output.

For the **pipeline** deployment events, add the connection string as a **secret
pipeline variable** in Azure DevOps (Pipelines → Edit → Variables):

```bash
cd infra/live/shared/monitoring
terragrunt output -raw connection_string
# Add as secret variable: APPLICATIONINSIGHTS_CONNECTION_STRING
```

When the variable is absent, the deployment-event step simply prints a skip
message — nothing breaks.

## Alerts (optional)

Alerts are defined in the `monitoring` module but **off by default**. Provide an
email to create an action group plus two metric alerts (failed requests, server
exceptions):

```hcl
# infra/live/shared/monitoring/terragrunt.hcl
inputs = {
  # ...
  alert_email = "you@example.com"
}
```

Then `cd infra/live/shared/monitoring && terragrunt apply`.

## Example KQL queries

Run these in the Application Insights / Log Analytics **Logs** blade.

Request volume and p95 latency by environment, last 24h:

```kusto
requests
| where timestamp > ago(24h)
| summarize count(), p95=percentile(duration, 95) by cloud_RoleName, bin(timestamp, 1h)
| render timechart
```

Failure rate by endpoint:

```kusto
requests
| where timestamp > ago(24h)
| summarize total=count(), failed=countif(success == false) by name
| extend failure_rate = round(100.0 * failed / total, 2)
| order by failure_rate desc
```

Open-Meteo dependency health:

```kusto
dependencies
| where timestamp > ago(24h) and type == "HTTP"
| summarize calls=count(), failures=countif(success == false), p95=percentile(duration,95)
    by target
```

Deployments and change-failure rate (DORA):

```kusto
customEvents
| where name == "Deployment" and timestamp > ago(30d)
| extend env = tostring(customDimensions.environment), result = tostring(customDimensions.result)
| summarize deployments=count(), failures=countif(result == "Failed") by env
| extend change_failure_rate = round(100.0 * failures / deployments, 2)
```

## Dashboards

A curated **Azure Monitor Workbook** ships as code in the monitoring module
([infra/modules/monitoring/workbook.tf](../infra/modules/monitoring/workbook.tf),
`azurerm_application_insights_workbook`). It combines pipeline and app health in
one view:

- **CI/CD (DORA):** deployment frequency per environment, change-failure rate.
- **App:** request rate & p95 latency by environment, request failures by
  operation, Open-Meteo dependency health.

Open it in the portal: **Application Insights `appi-weather` → Workbooks →
"Weather — app & pipeline health"**. Because it's Terraform, it is recreated
identically on every deploy and reviewable in PRs.

For pipeline-build metrics specifically (pass rate, test trends, coverage), use
the Azure DevOps **Analytics** views and an **ADO Dashboard** (see "Where to
watch the pipeline" above) — those live in Azure DevOps, not Azure Monitor.
