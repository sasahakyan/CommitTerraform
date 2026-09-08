output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "service_url" {
  value = module.api.uri
}

output "health_url" {
  value = "${module.api.uri}/health"
}

output "cloud_run_service" {
  value = module.api.name
}

output "migration_job" {
  value = module.api.job_name
}

output "image_repository" {
  value = module.artifact_registry.repository_url
}

output "sql_instance" {
  value = module.cloudsql.instance_name
}

output "sql_private_ip" {
  value = module.cloudsql.private_ip
}

output "runtime_service_account" {
  value = google_service_account.api_runtime.email
}

output "github_service_variables" {
  description = "GitHub Environment variables for the commitService repository."
  value       = <<-EOT
    gh variable set IMAGE_REPOSITORY  -e ${var.environment} -b '${module.artifact_registry.repository_url}/api'
    gh variable set CLOUD_RUN_SERVICE -e ${var.environment} -b '${module.api.name}'
    gh variable set MIGRATION_JOB     -e ${var.environment} -b '${module.api.job_name}'
  EOT
}
