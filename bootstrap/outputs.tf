output "project_id" {
  value = module.project.project_id
}

output "project_number" {
  value = module.project.project_number
}

output "state_bucket" {
  value = module.state_bucket.name
}

output "wif_provider" {
  description = "workload_identity_provider for google-github-actions/auth"
  value       = module.github_wif.provider_name
}

output "terraform_ci_service_account" {
  value = module.github_wif.service_account_emails["terraform-ci"]
}

output "app_deploy_service_account" {
  value = module.github_wif.service_account_emails["app-deploy"]
}

output "next_steps" {
  description = "Values to place in the environment stack and in GitHub Environment variables."
  value       = <<-EOT
    # tfvars/${var.environment}.tfvars
    project_id                 = "${module.project.project_id}"
    deployer_service_account   = "${module.github_wif.service_account_emails["app-deploy"]}"

    # backend/${var.environment}.hcl
    bucket = "${module.state_bucket.name}"
    prefix = "env/${var.environment}"

    # GitHub Environment "${var.environment}" variables (CommitTerraform)
    gh variable set WIF_PROVIDER        -e ${var.environment} -b '${module.github_wif.provider_name}'
    gh variable set GCP_SERVICE_ACCOUNT -e ${var.environment} -b '${module.github_wif.service_account_emails["terraform-ci"]}'

    # GitHub Environment "${var.environment}" variables (commitService)
    gh variable set WIF_PROVIDER        -e ${var.environment} -b '${module.github_wif.provider_name}'
    gh variable set GCP_SERVICE_ACCOUNT -e ${var.environment} -b '${module.github_wif.service_account_emails["app-deploy"]}'
    gh variable set GCP_PROJECT_ID      -e ${var.environment} -b '${module.project.project_id}'
    gh variable set GCP_REGION          -e ${var.environment} -b '${var.region}'
  EOT
}
