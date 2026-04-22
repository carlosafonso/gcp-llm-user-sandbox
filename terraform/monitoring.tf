resource "google_project_iam_member" "admin_monitoring_viewer" {
  for_each = toset(var.admin_principals)
  project  = google_project.management.project_id
  role     = "roles/monitoring.viewer"
  member   = each.value
}

# Add each sandbox project to the management project's metrics scope so the
# dashboard can query Vertex AI metrics across all sandboxes from one place.
resource "google_monitoring_monitored_project" "sandbox_scope" {
  for_each      = local.employee_map
  metrics_scope = "locations/global/metricsScopes/${google_project.management.project_id}"
  name          = google_project.employee_sandbox[each.key].project_id

  depends_on = [google_project_service.management_monitoring]
}

resource "google_monitoring_dashboard" "llm_usage" {
  project = google_project.management.project_id

  dashboard_json = jsonencode({
    displayName = "LLM Usage"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 2
          widget = {
            title = "Total Token Throughput"
            scorecard = {
              timeSeriesQuery = {
                prometheusQuery = "sum(rate({\"__name__\"=\"aiplatform.googleapis.com/publisher/online_serving/consumed_token_throughput\",\"monitored_resource\"=\"aiplatform.googleapis.com/PublisherModel\"}[$${__interval}]))"
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 0
          width  = 6
          height = 2
          widget = {
            title = "Total Invocation Rate"
            scorecard = {
              timeSeriesQuery = {
                prometheusQuery = "sum(rate({\"__name__\"=\"aiplatform.googleapis.com/publisher/online_serving/model_invocation_count\",\"monitored_resource\"=\"aiplatform.googleapis.com/PublisherModel\"}[$${__interval}]))"
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          xPos   = 0
          yPos   = 2
          width  = 6
          height = 4
          widget = {
            title = "Total Tokens by User Project"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  prometheusQuery = "sum by (\"resource_container\")(increase({\"__name__\"=\"aiplatform.googleapis.com/publisher/online_serving/consumed_token_throughput\",\"monitored_resource\"=\"aiplatform.googleapis.com/PublisherModel\"}[$${__interval}]))"
                }
                plotType = "STACKED_BAR"
              }]
              yAxis = {
                label = "tokens"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 2
          width  = 6
          height = 4
          widget = {
            title = "Total Tokens by Model"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  prometheusQuery = "sum by (\"model_user_id\")(increase({\"__name__\"=\"aiplatform.googleapis.com/publisher/online_serving/consumed_token_throughput\",\"monitored_resource\"=\"aiplatform.googleapis.com/PublisherModel\"}[$${__interval}]))"
                }
                plotType = "STACKED_BAR"
              }]
              yAxis = {
                label = "tokens"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          xPos   = 0
          yPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Token Throughput by User Project (tokens/s)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  prometheusQuery = "sum by (\"resource_container\")(rate({\"__name__\"=\"aiplatform.googleapis.com/publisher/online_serving/consumed_token_throughput\",\"monitored_resource\"=\"aiplatform.googleapis.com/PublisherModel\"}[$${__interval}]))"
                }
                plotType = "STACKED_AREA"
              }]
              yAxis = {
                label = "tokens/s"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Request Count by User Project"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  prometheusQuery = "sum by (\"resource_container\")(rate({\"__name__\"=\"aiplatform.googleapis.com/publisher/online_serving/model_invocation_count\",\"monitored_resource\"=\"aiplatform.googleapis.com/PublisherModel\"}[$${__interval}]))"
                }
                plotType = "STACKED_AREA"
              }]
              yAxis = {
                label = "requests/s"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })

  depends_on = [google_project_service.management_monitoring]
}
