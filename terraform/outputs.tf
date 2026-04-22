output "sandbox_root_folder" {
  value = google_folder.sandbox_root.name
}

output "management_project_id" {
  value = google_project.management.project_id
}

output "employee_sandboxes" {
  value = {
    for email, project in google_project.employee_sandbox : email => project.project_id
  }
}

output "custom_role_name" {
  value = google_organization_iam_custom_role.vertex_inference_user.name
}

output "llm_usage_dashboard_url" {
  value = "https://console.cloud.google.com/monitoring/dashboards/builder/${split("/", google_monitoring_dashboard.llm_usage.id)[3]}?project=${google_project.management.project_id}"
}
