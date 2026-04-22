provider "google" {
  region = var.region
}

# Separate provider alias for resources that require a quota project with user credentials.
# Used only by google_billing_budget, which calls billingbudgets.googleapis.com.
provider "google" {
  alias                 = "billing"
  region                = var.region
  user_project_override = var.quota_project_id != ""
  billing_project       = var.quota_project_id != "" ? var.quota_project_id : null
}

resource "google_folder" "sandbox_root" {
  display_name = var.sandbox_folder_name
  parent       = var.parent_folder_id
}

resource "random_id" "mgmt_project_suffix" {
  byte_length = 4
}

resource "google_project" "management" {
  name            = "Management and Observability"
  project_id      = "mgmt-obs-${random_id.mgmt_project_suffix.hex}"
  folder_id       = google_folder.sandbox_root.name
  billing_account = var.billing_account_id
}
