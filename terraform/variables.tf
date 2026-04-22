terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

variable "org_id" {
  description = "The Google Cloud Organization ID."
  type        = string
}

variable "billing_account_id" {
  description = "The Billing Account ID to associate projects with."
  type        = string
}

variable "parent_folder_id" {
  description = "The parent folder ID where the sandbox folder will be created (format: folders/12345)."
  type        = string
}

variable "sandbox_folder_name" {
  description = "The name of the root folder for all sandboxes."
  type        = string
  default     = "Employee Sandboxes"
}

variable "employees" {
  description = "List of employee objects with their email addresses."
  type = list(object({
    email = string
  }))
  default = []
}

variable "region" {
  description = "Default region for resources."
  type        = string
  default     = "us-central1"
}

variable "quota_project_id" {
  description = "Project ID used as the API quota project for the Google provider. Set to the management project ID after it is first created."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly spend limit in USD applied to each employee sandbox project."
  type        = number
}

variable "budget_alert_email" {
  description = "Email address that receives budget threshold alert notifications."
  type        = string
}

variable "admin_principals" {
  description = "List of principals (e.g. user:alice@example.com, group:admins@example.com) granted Monitoring Viewer on the management project."
  type        = list(string)
  default     = []
}

variable "force_destroy" {
  description = "When true, allows sandbox projects and the function source bucket to be deleted by terraform destroy. Keep false in production."
  type        = bool
  default     = false
}

variable "enable_pubsub_budget_enforcement" {
  description = "When true, wires each billing budget to the budget-alerts Pub/Sub topic so the budget-enforcer Cloud Function can automatically disable Vertex AI on overspend. Set to false in GCP environments where the Billing Budgets service account cannot be granted pubsub.publisher via the IAM API."
  type        = bool
  default     = true
}
