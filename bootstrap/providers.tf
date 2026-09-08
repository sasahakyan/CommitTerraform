provider "google" {
  region                = var.region
  user_project_override = true
  billing_project       = var.quota_project
}
