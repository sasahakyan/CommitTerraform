variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "environment must be dev, stg or prd."
  }
}

variable "project_id" {
  description = "Project created by the bootstrap stack for this environment."
  type        = string
}

variable "region" {
  description = "Single region for every resource. EU only until Meridian confirms data residency; US traffic would be a second stack, not a second region in this one."
  type        = string
  default     = "europe-west1"
}

variable "name_prefix" {
  type    = string
  default = "meridian"
}

variable "candidate_name" {
  description = "Reported by /health as required by the exercise."
  type        = string
}

variable "deployer_service_account" {
  description = "Email of the CI identity that deploys Cloud Run revisions (bootstrap output app_deploy_service_account)."
  type        = string
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}

# ----- Cloud SQL -----
variable "sql_tier" {
  type    = string
  default = "db-f1-micro"
}

variable "sql_availability_type" {
  type    = string
  default = "ZONAL"
}

variable "sql_disk_size_gb" {
  type    = number
  default = 10
}

variable "sql_deletion_protection" {
  type    = bool
  default = true
}

variable "sql_backups_enabled" {
  type    = bool
  default = true
}

variable "sql_point_in_time_recovery" {
  type    = bool
  default = true
}

variable "sql_backup_location" {
  description = "eu keeps backups inside the EU multi-region."
  type        = string
  default     = "eu"
}

# ----- Cloud Run -----
variable "run_min_instances" {
  type    = number
  default = 0
}

variable "run_max_instances" {
  type    = number
  default = 3
}

variable "run_deletion_protection" {
  type    = bool
  default = true
}

variable "run_public" {
  description = "Expose the service to unauthenticated callers. Required for the exercise's public /health."
  type        = bool
  default     = true
}

# ----- Access -----
variable "viewer_members" {
  description = "IAM members granted roles/viewer on the project (reviewers)."
  type        = list(string)
  default     = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
