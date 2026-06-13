# Dashboard-as-code: an Azure Monitor Workbook over this Application Insights,
# combining CI/CD signals (DORA deployment events emitted by the pipeline) and
# app health (requests, failures, Open-Meteo dependency). Open it from the
# resource: Application Insights -> Workbooks -> "Weather — app & pipeline".
#
# Workbook content is plain JSON (queries + markdown). A bad query only breaks
# its own tile, so this is low-risk to ship.

resource "azurerm_application_insights_workbook" "health" {
  # Workbook resource name must be a GUID; fixed so applies are idempotent.
  # Assumes a single monitoring unit (true here) — two instances in one
  # subscription would collide on this name.
  name                = "0b1c2d3e-4f56-4789-abcd-ef0123456789"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = azurerm_resource_group.monitoring.location
  display_name        = "Weather — app & pipeline health"
  # Scope the workbook to this component (provider expects a lowercased id).
  source_id = lower(azurerm_application_insights.ai.id)
  tags      = var.tags

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type    = 1
        name    = "title"
        content = { json = "# Weather — app & pipeline health\nDeployment (DORA) signals from the Azure DevOps pipeline and runtime health of the app. Environments are separated by OpenTelemetry cloud role name (`weather-<env>`)." }
      },
      {
        type    = 1
        name    = "deploy-header"
        content = { json = "## CI/CD — deployments (DORA)" }
      },
      {
        type = 3
        name = "deployment-frequency"
        content = {
          version       = "KqlItem/1.0"
          query         = "customEvents\n| where name == 'Deployment'\n| extend env = tostring(customDimensions.environment)\n| summarize deployments = count() by bin(timestamp, 1d), env\n| render columnchart"
          size          = 0
          title         = "Deployment frequency (per day, by environment)"
          timeContext   = { durationMs = 2592000000 }
          queryType     = 0
          resourceType  = "microsoft.insights/components"
          visualization = "barchart"
        }
      },
      {
        type = 3
        name = "change-failure-rate"
        content = {
          version       = "KqlItem/1.0"
          query         = "customEvents\n| where name == 'Deployment'\n| extend env = tostring(customDimensions.environment), result = tostring(customDimensions.result)\n| summarize deployments = count(), failed = countif(result == 'Failed') by env\n| extend change_failure_rate_pct = round(100.0 * failed / deployments, 1)\n| project env, deployments, failed, change_failure_rate_pct"
          size          = 0
          title         = "Change-failure rate (last 30 days)"
          timeContext   = { durationMs = 2592000000 }
          queryType     = 0
          resourceType  = "microsoft.insights/components"
          visualization = "table"
        }
      },
      {
        type    = 1
        name    = "app-header"
        content = { json = "## App — runtime health" }
      },
      {
        type = 3
        name = "request-rate-latency"
        content = {
          version       = "KqlItem/1.0"
          query         = "requests\n| summarize requests = count(), p95_ms = round(percentile(duration, 95), 1) by bin(timestamp, 1h), cloud_RoleName\n| render timechart"
          size          = 0
          title         = "Request rate & p95 latency (by environment)"
          timeContext   = { durationMs = 86400000 }
          queryType     = 0
          resourceType  = "microsoft.insights/components"
          visualization = "timechart"
        }
      },
      {
        type = 3
        name = "request-failures"
        content = {
          version       = "KqlItem/1.0"
          query         = "requests\n| summarize total = count(), failed = countif(success == false) by name\n| extend failure_rate_pct = round(100.0 * failed / total, 1)\n| order by failure_rate_pct desc"
          size          = 0
          title         = "Requests & failure rate by operation (last 24h)"
          timeContext   = { durationMs = 86400000 }
          queryType     = 0
          resourceType  = "microsoft.insights/components"
          visualization = "table"
        }
      },
      {
        type = 3
        name = "dependency-health"
        content = {
          version       = "KqlItem/1.0"
          query         = "dependencies\n| where type == 'HTTP'\n| summarize calls = count(), failures = countif(success == false), p95_ms = round(percentile(duration, 95), 1) by target\n| order by calls desc"
          size          = 0
          title         = "Open-Meteo dependency health (last 24h)"
          timeContext   = { durationMs = 86400000 }
          queryType     = 0
          resourceType  = "microsoft.insights/components"
          visualization = "table"
        }
      }
    ]
    fallbackResourceIds = [azurerm_application_insights.ai.id]
    "$schema"           = "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
  })
}
