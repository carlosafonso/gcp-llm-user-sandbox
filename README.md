# LLM Usage Tracker

Terraform infrastructure for managing employee sandbox GCP projects with LLM usage tracking and budget enforcement via Vertex AI / Gemini models.

> [!IMPORTANT]
> **DISCLAIMER:** This solution is **not necessarily production-ready** and is intended only as a **starting point for customization** to meet specific customer needs. Use it at your own risk and ensure thorough testing and security audits before deploying to a production environment.

## What it does

- Creates a dedicated GCP folder (`Employee Sandboxes`) under a parent folder.
- Provisions one sandbox GCP project per employee with Vertex AI enabled and scoped permissions (inference only).
- Attaches a monthly billing budget to each sandbox and sends alerts when thresholds are breached.
- Deploys a Cloud Function (`budget-enforcer`) that automatically disables `aiplatform.googleapis.com` on a sandbox project when its budget is fully exhausted (100% threshold).
- Creates a management project with a Cloud Monitoring dashboard aggregating token throughput and invocation metrics across all sandboxes.

## Architecture

```
org
└── <parent folder>
    └── Employee Sandboxes (google_folder)
        ├── mgmt-obs-<id>  (management project)
        │   ├── Cloud Monitoring dashboard  (LLM Usage)
        │   ├── Pub/Sub topic               (budget-alerts)
        │   └── Cloud Function Gen 2        (budget-enforcer)
        ├── <employee-a>-sandbox-<id>
        ├── <employee-b>-sandbox-<id>
        └── ...
```

Each sandbox project is added to the management project's metrics scope so the dashboard can query all of them from one place.

## Prerequisites

- Terraform >= 1.0
- A GCP organization with billing enabled
- A service account or user credentials with:
  - `resourcemanager.folders.create` on the parent folder
  - `billing.accounts.get` and `billing.resourceAssociations.create` on the billing account
  - `billing.budgets.create` on the billing account (for budget resources)
  - `iam.roles.create` at the org level (for the custom Vertex AI role)

## Usage

### First apply

```bash
cd terraform

cat > terraform.tfvars <<EOF
org_id             = "123456789"
billing_account_id = "XXXXXX-XXXXXX-XXXXXX"
parent_folder_id   = "folders/987654321"
monthly_budget_usd = 50
budget_alert_email = "platform-team@example.com"
admin_principals   = ["user:admin@example.com"]
employees = [
  { email = "alice@example.com" },
  { email = "bob@example.com" },
]
EOF

terraform init
terraform apply
```

### Subsequent applies

After the first apply, set `quota_project_id` to the management project ID output to avoid billing quota issues with the Billing Budgets API:

```bash
# Get the management project ID from outputs
terraform output management_project_id

# Add to terraform.tfvars
echo 'quota_project_id = "mgmt-obs-<id>"' >> terraform.tfvars

terraform apply
```

## Variables

| Name | Description | Default |
|---|---|---|
| `org_id` | GCP Organization ID | required |
| `billing_account_id` | Billing account to attach to all projects | required |
| `parent_folder_id` | Parent folder where the sandbox folder is created | required |
| `monthly_budget_usd` | Monthly spend limit per sandbox (USD) | required |
| `budget_alert_email` | Email for budget alert notifications | required |
| `employees` | List of `{ email }` objects, one per employee | `[]` |
| `sandbox_folder_name` | Display name of the root sandbox folder | `"Employee Sandboxes"` |
| `region` | Default region for resources | `"us-central1"` |
| `quota_project_id` | Project used as API quota project for the billing provider | `""` |
| `admin_principals` | Principals granted Monitoring Viewer on the management project | `[]` |
| `force_destroy` | Allow sandbox projects and the function source bucket to be deleted by `terraform destroy`. Keep `false` in production. | `false` |
| `enable_pubsub_budget_enforcement` | Wire budgets to the Pub/Sub topic to enable automatic Vertex AI shutdown on overspend. See [Budget enforcement](#budget-enforcement). | `true` |

## Outputs

| Name | Description |
|---|---|
| `management_project_id` | ID of the management/observability project |
| `sandbox_root_folder` | Resource name of the sandbox folder |
| `employee_sandboxes` | Map of employee email → sandbox project ID |
| `custom_role_name` | Full name of the Vertex AI Inference User custom role |
| `llm_usage_dashboard_url` | Direct URL to the Cloud Monitoring LLM Usage dashboard |

## Dashboards

The management project includes an **LLM Usage** Cloud Monitoring dashboard that aggregates Vertex AI metrics across all sandbox projects from a single view. After apply, the direct URL is available via `terraform output llm_usage_dashboard_url`.

The dashboard contains six panels:

| Panel | Type | Description |
|---|---|---|
| Total Token Throughput | Scorecard | Real-time token consumption rate across all sandboxes |
| Total Invocation Rate | Scorecard | Real-time model call rate across all sandboxes |
| Total Tokens by User Project | Stacked bar | Cumulative token usage broken down per sandbox project |
| Total Tokens by Model | Stacked bar | Cumulative token usage broken down per model |
| Token Throughput by User Project | Stacked area | Token throughput (tokens/s) over time per sandbox project |
| Request Count by User Project | Stacked area | Invocation rate (requests/s) over time per sandbox project |

Principals listed in `admin_principals` are granted `roles/monitoring.viewer` on the management project and can view the dashboard without broader access.

## Budget enforcement

When a sandbox project's spend reaches 100% of the monthly budget, the Billing Budgets alert publishes a message to the `budget-alerts` Pub/Sub topic. This triggers the `budget-enforcer` Cloud Function via Eventarc, which calls the Service Usage API to disable `aiplatform.googleapis.com` on that project. The function is idempotent — a 404 (already disabled) is treated as success.

> **Note:** When `pubsub_topic` is set on a billing budget, GCP's backend automatically grants `billing-budgets@system.gserviceaccount.com` the `pubsub.publisher` role on the topic. In some restricted GCP environments this internal IAM grant is not permitted, causing the budget update to fail with `400: Precondition check failed`. If you hit this error, set `enable_pubsub_budget_enforcement = false` in your `terraform.tfvars` — budget alert emails will still be sent, but the automatic Vertex AI shutdown will be disabled.

## Project structure

```
.
├── terraform/
│   ├── main.tf          # Provider config, management project, sandbox folder
│   ├── variables.tf     # Input variables
│   ├── outputs.tf       # Outputs
│   ├── sandboxes.tf     # Per-employee sandbox projects and IAM
│   ├── budgets.tf       # Billing budgets and monitoring notification channel
│   ├── monitoring.tf    # Cloud Monitoring dashboard and metrics scopes
│   ├── functions.tf     # Pub/Sub, Cloud Function, and related IAM
│   ├── iam.tf           # Org-level custom Vertex AI role
│   └── terraform.tfvars # (gitignored) your variable values
└── functions/
    └── budget_enforcer/
        ├── main.py          # Cloud Function entry point
        └── requirements.txt # Python dependencies
```
