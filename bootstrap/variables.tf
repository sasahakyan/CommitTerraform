variable "environment" {
  description = "dev, stg or prd. One bootstrap per environment; each gets its own project, state bucket and CI identities."
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "environment must be dev, stg or prd."
  }
}

variable "org_id" {
  type = string
}

variable "folder_id" {
  description = "Optional folder. When set, the project is created there instead of directly under the org."
  type        = string
  default     = null
}

variable "billing_account" {
  type = string
}

variable "quota_project" {
  description = "Existing project used for API quota while the new project is being created."
  type        = string
}

variable "project_prefix" {
  type    = string
  default = "meridian"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "github_owner" {
  type = string
}

variable "terraform_repository" {
  description = "Repository allowed to run terraform plan/apply."
  type        = string
  default     = "CommitTerraform"
}

variable "service_repository" {
  description = "Repository allowed to push images and deploy Cloud Run revisions."
  type        = string
  default     = "commitService"
}

variable "project_deletion_policy" {
  description = "DELETE for disposable environments, PREVENT for production."
  type        = string
  default     = "PREVENT"
}

variable "labels" {
  type    = map(string)
  default = {}
}
