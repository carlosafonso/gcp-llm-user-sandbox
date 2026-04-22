# --- APIs ---

resource "google_project_service" "management_pubsub" {
  project            = google_project.management.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "management_cloudfunctions" {
  project            = google_project.management.project_id
  service            = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "management_cloudbuild" {
  project            = google_project.management.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "management_run" {
  project            = google_project.management.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "management_artifactregistry" {
  project            = google_project.management.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "management_eventarc" {
  project            = google_project.management.project_id
  service            = "eventarc.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "management_billingbudgets" {
  project            = google_project.management.project_id
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "management_serviceusage" {
  project            = google_project.management.project_id
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
}

# --- Pub/Sub ---

resource "google_pubsub_topic" "budget_alerts" {
  name    = "budget-alerts"
  project = google_project.management.project_id

  depends_on = [google_project_service.management_pubsub]
}


# --- Cloud Build service account ---

resource "google_project_iam_member" "cloudbuild_builder" {
  project = google_project.management.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_project.management.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_logging" {
  project = google_project.management.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_project.management.number}-compute@developer.gserviceaccount.com"
}

# --- Function service account ---

resource "google_service_account" "budget_enforcer" {
  account_id   = "budget-enforcer-fn"
  display_name = "Budget Enforcer Cloud Function SA"
  project      = google_project.management.project_id
}

resource "google_project_iam_member" "budget_enforcer_run_invoker" {
  project = google_project.management.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.budget_enforcer.email}"
}

resource "google_project_iam_member" "budget_enforcer_eventarc_receiver" {
  project = google_project.management.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.budget_enforcer.email}"
}

resource "google_project_iam_member" "budget_enforcer_ar_reader" {
  project = google_project.management.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.budget_enforcer.email}"
}

# Allows Pub/Sub to create auth tokens for the Eventarc trigger.
resource "google_project_iam_member" "pubsub_token_creator" {
  project = google_project.management.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${google_project.management.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "budget_enforcer_service_usage_admin" {
  for_each = local.employee_map
  project  = google_project.employee_sandbox[each.key].project_id
  role     = "roles/serviceusage.serviceUsageAdmin"
  member   = "serviceAccount:${google_service_account.budget_enforcer.email}"
}

# --- Function source ---

resource "google_storage_bucket" "function_source" {
  name                        = "${google_project.management.project_id}-fn-source"
  project                     = google_project.management.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy
}

data "archive_file" "budget_enforcer" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/budget_enforcer"
  output_path = "${path.module}/.terraform/budget_enforcer.zip"
}

resource "google_storage_bucket_object" "budget_enforcer_source" {
  name   = "budget_enforcer_${data.archive_file.budget_enforcer.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.budget_enforcer.output_path
}

# --- Cloud Function (Gen 2) ---

resource "google_cloudfunctions2_function" "budget_enforcer" {
  name     = "budget-enforcer"
  project  = google_project.management.project_id
  location = var.region

  build_config {
    runtime         = "python312"
    entry_point     = "disable_vertex_on_budget_alert"
    service_account = "projects/${google_project.management.project_id}/serviceAccounts/${google_project.management.number}-compute@developer.gserviceaccount.com"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.budget_enforcer_source.name
      }
    }
  }

  service_config {
    service_account_email = google_service_account.budget_enforcer.email
    min_instance_count    = 0
    max_instance_count    = 3
    available_memory      = "256M"
    timeout_seconds       = 60
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.budget_alerts.id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.budget_enforcer.email
  }

  depends_on = [
    google_project_service.management_cloudfunctions,
    google_project_service.management_run,
    google_project_service.management_cloudbuild,
    google_project_service.management_artifactregistry,
    google_project_service.management_eventarc,
  ]
}
