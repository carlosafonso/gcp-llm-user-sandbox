resource "google_organization_iam_custom_role" "vertex_inference_user" {
  role_id     = "vertexAIInferenceUser"
  org_id      = var.org_id
  title       = "Vertex AI Inference User"
  description = "Allows calling Vertex AI Gemini and Anthropic models for prediction."
  permissions = [
    "aiplatform.endpoints.predict"
  ]
}
