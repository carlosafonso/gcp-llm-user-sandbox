resource "google_project_service" "management_monitoring" {
  project            = google_project.management.project_id
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "budget_email" {
  project      = google_project.management.project_id
  display_name = "Budget Alert Email"
  type         = "email"
  labels = {
    email_address = var.budget_alert_email
  }
  depends_on = [google_project_service.management_monitoring]
}

resource "google_billing_budget" "employee_sandbox" {
  provider        = google.billing
  for_each        = local.employee_map
  billing_account = var.billing_account_id

  depends_on = [google_project_service.management_billingbudgets]
  display_name    = "${each.value.prefix} Sandbox Budget"

  budget_filter {
    calendar_period = "MONTH"
    projects        = ["projects/${google_project.employee_sandbox[each.key].number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(floor(var.monthly_budget_usd))
    }
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.budget_email.id]
    pubsub_topic                     = var.enable_pubsub_budget_enforcement ? google_pubsub_topic.budget_alerts.id : null
    disable_default_iam_recipients   = false
  }
}
