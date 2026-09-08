# Environment stack. Identical code for dev, stg and prd; only
# tfvars/<env>.tfvars and backend/<env>.hcl differ.

locals {
  prefix = "${var.name_prefix}-${var.environment}"
  labels = merge({
    environment = var.environment
    customer    = "meridian"
    managed_by  = "terraform"
  }, var.labels)

  service_name       = "${local.prefix}-api"
  migration_job_name = "${local.prefix}-api-migrate"
  db_password_secret = "${local.prefix}-db-password"
  third_party_secret = "${local.prefix}-third-party-api-token"
  deployer_member    = "serviceAccount:${var.deployer_service_account}"
}

# ---------------------------------------------------------------- network
module "network" {
  source = "git::https://github.com/sasahakyan/commitTemplates.git//terraform/modules/network?ref=v0.1.3"

  project_id  = var.project_id
  name        = "${local.prefix}-vpc"
  region      = var.region
  subnet_cidr = var.subnet_cidr
}

# ---------------------------------------------------------------- images
module "artifact_registry" {
  source = "git::https://github.com/sasahakyan/commitTemplates.git//terraform/modules/artifact-registry?ref=v0.1.3"

  project_id    = var.project_id
  location      = var.region
  repository_id = "${local.prefix}-images"
  description   = "Meridian API images (${var.environment})"
  labels        = local.labels
}

# ---------------------------------------------------------------- identity
# Runtime identity of the API. Holds exactly two permissions: read its two
# secrets. Database access is by network path plus password, no IAM role.
resource "google_service_account" "api_runtime" {
  project      = var.project_id
  account_id   = "${local.prefix}-api-run"
  display_name = "Meridian API runtime (${var.environment})"
}

# The deploy pipeline may set this identity on new revisions, and only this one.
resource "google_service_account_iam_member" "deployer_acts_as_runtime" {
  service_account_id = google_service_account.api_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = local.deployer_member
}

# ---------------------------------------------------------------- database
resource "random_id" "sql" {
  # Cloud SQL keeps a deleted instance name reserved for about a week.
  byte_length = 2
}

module "cloudsql" {
  source = "git::https://github.com/sasahakyan/commitTemplates.git//terraform/modules/cloudsql?ref=v0.1.3"

  # The PSA peering must exist before an instance can ask for a private IP.
  depends_on = [module.network]

  project_id             = var.project_id
  name                   = "${local.prefix}-pg-${random_id.sql.hex}"
  region                 = var.region
  network_id             = module.network.network_id
  tier                   = var.sql_tier
  availability_type      = var.sql_availability_type
  disk_size_gb           = var.sql_disk_size_gb
  deletion_protection    = var.sql_deletion_protection
  backups_enabled        = var.sql_backups_enabled
  point_in_time_recovery = var.sql_point_in_time_recovery
  backup_location        = var.sql_backup_location
  database_name          = "meridian"
  user_name              = "meridian_api"
  password_rotation      = var.sql_password_rotation
  labels                 = local.labels
}

# ---------------------------------------------------------------- secrets
# Placeholder for the third-party token. Meridian owns the real value and
# adds it as a new version out of band; nothing in this repository or its
# state ever needs to know it.
resource "random_password" "third_party_placeholder" {
  length  = 40
  special = false
}

module "secrets" {
  source = "git::https://github.com/sasahakyan/commitTemplates.git//terraform/modules/secrets?ref=v0.1.3"

  project_id = var.project_id
  location   = var.region
  labels     = local.labels

  secrets = {
    (local.db_password_secret) = { accessors = { api-runtime = google_service_account.api_runtime.member } }
    (local.third_party_secret) = { accessors = { api-runtime = google_service_account.api_runtime.member } }
  }

  secret_values = {
    (local.db_password_secret) = module.cloudsql.user_password
    (local.third_party_secret) = random_password.third_party_placeholder.result
  }
}

# ---------------------------------------------------------------- compute
module "api" {
  source = "git::https://github.com/sasahakyan/commitTemplates.git//terraform/modules/cloudrun-service?ref=v0.1.3"

  project_id            = var.project_id
  name                  = local.service_name
  region                = var.region
  service_account_email = google_service_account.api_runtime.email
  network_id            = module.network.network_id
  subnet_id             = module.network.subnet_id
  public                = var.run_public
  min_instances         = var.run_min_instances
  max_instances         = var.run_max_instances
  deletion_protection   = var.run_deletion_protection
  startup_probe_path    = "/"
  labels                = local.labels

  env = {
    CANDIDATE_NAME           = var.candidate_name
    GCP_REGION               = var.region
    GCP_PROJECT              = var.project_id
    DB_HOST                  = module.cloudsql.private_ip
    DB_PORT                  = "5432"
    DB_NAME                  = module.cloudsql.database_name
    DB_USER                  = module.cloudsql.user_name
    THIRD_PARTY_TOKEN_SECRET = module.secrets.secret_names[local.third_party_secret]
  }

  secret_env = {
    DB_PASSWORD = { secret_id = module.secrets.secret_ids[local.db_password_secret] }
  }

  job = {
    name            = local.migration_job_name
    command         = ["alembic"]
    args            = ["upgrade", "head"]
    timeout_seconds = 600
  }
}

# ---------------------------------------------------------------- access
resource "google_project_iam_member" "viewers" {
  for_each = toset(var.viewer_members)

  project = var.project_id
  role    = "roles/viewer"
  member  = each.value
}
