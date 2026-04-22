locals {
  # Map employee objects to a map keyed by their email for easier iteration
  # and prefix extraction for unique project IDs.
  employee_map = {
    for emp in var.employees : emp.email => {
      email  = emp.email
      prefix = split("@", emp.email)[0]
    }
  }
}

resource "random_id" "project_suffix" {
  for_each    = local.employee_map
  byte_length = 2
}

resource "google_project" "employee_sandbox" {
  for_each        = local.employee_map
  name            = "${each.value.prefix} Sandbox"
  project_id      = "${replace(each.value.prefix, ".", "-")}-sandbox-${random_id.project_suffix[each.key].hex}"
  folder_id       = google_folder.sandbox_root.name
  billing_account = var.billing_account_id
  deletion_policy = var.force_destroy ? "DELETE" : "PREVENT"
}

resource "google_project_service" "aiplatform" {
  for_each = local.employee_map
  project  = google_project.employee_sandbox[each.key].project_id
  service  = "aiplatform.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_iam_member" "employee_vertex_user" {
  for_each = local.employee_map
  project  = google_project.employee_sandbox[each.key].project_id
  role     = google_organization_iam_custom_role.vertex_inference_user.name
  member   = "user:${each.value.email}"
}

resource "google_project_iam_member" "employee_procurement_admin" {
  for_each = local.employee_map
  project  = google_project.employee_sandbox[each.key].project_id
  role     = "roles/consumerprocurement.orderAdmin"
  member   = "user:${each.value.email}"
}

resource "google_project_iam_member" "employee_project_viewer" {
  for_each = local.employee_map
  project  = google_project.employee_sandbox[each.key].project_id
  role     = "roles/viewer"
  member   = "user:${each.value.email}"
}
