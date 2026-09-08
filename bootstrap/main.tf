# Bootstrap for one environment: project, APIs, Terraform state bucket and
# keyless CI identities. Applied once from an operator laptop (the only
# manual step in the repository), then its own state is migrated into the
# bucket it created. See scripts/bootstrap.sh and the README.

locals {
  suffix     = random_id.project.hex
  project_id = "${var.project_prefix}-${var.environment}-${local.suffix}"
  labels = merge({
    environment = var.environment
    customer    = "meridian"
    managed_by  = "terraform"
  }, var.labels)

  apis = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]

  # Least privilege that still lets Terraform manage the environment stack.
  # roles/editor would be shorter and is deliberately not used.
  terraform_ci_roles = [
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/servicenetworking.networksAdmin",
    "roles/cloudsql.admin",
    "roles/secretmanager.admin",
    "roles/run.admin",
    "roles/artifactregistry.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
  ]

  # The deploy identity can push images and roll revisions, nothing else.
  # Permission to act as the runtime service account is granted in the
  # environment stack on that one account.
  deploy_ci_roles = [
    "roles/run.developer",
    "roles/artifactregistry.writer",
  ]
}

resource "random_id" "project" {
  byte_length = 2
}

module "project" {
  source = "git::https://github.com/sasahakyan/commitTemplates.git//terraform/modules/project?ref=v0.1.1"

  project_id      = local.project_id
  name            = "Meridian ${var.environment}"
  org_id          = var.org_id
  folder_id       = var.folder_id
  billing_account = var.billing_account
  apis            = local.apis
  labels          = local.labels
  deletion_policy = var.project_deletion_policy
}

module "github_wif" {
  source = "git::https://github.com/sasahakyan/commitTemplates.git//terraform/modules/github-wif?ref=v0.1.1"

  project_id   = module.project.project_id
  github_owner = var.github_owner

  service_accounts = {
    "terraform-ci" = {
      display_name  = "Terraform CI (${var.environment})"
      repository    = var.terraform_repository
      project_roles = local.terraform_ci_roles
    }
    "app-deploy" = {
      display_name  = "Cloud Run deploy (${var.environment})"
      repository    = var.service_repository
      project_roles = local.deploy_ci_roles
    }
  }
}

module "state_bucket" {
  source = "git::https://github.com/sasahakyan/commitTemplates.git//terraform/modules/state-bucket?ref=v0.1.1"

  project_id    = module.project.project_id
  name          = "${local.project_id}-tfstate"
  location      = var.region
  labels        = local.labels
  force_destroy = var.project_deletion_policy == "DELETE"
  admin_members = { terraform-ci = module.github_wif.service_account_members["terraform-ci"] }
}
