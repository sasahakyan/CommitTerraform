environment              = "dev"
project_id               = "meridian-dev-26aa"
deployer_service_account = "app-deploy@meridian-dev-26aa.iam.gserviceaccount.com"
region                   = "europe-west1"
candidate_name           = "Sahak Sahakyan"

# Disposable PoC: smallest tier, single zone, no deletion protection so the
# environment can be torn down with one command after the review.
sql_tier                   = "db-f1-micro"
sql_availability_type      = "ZONAL"
sql_deletion_protection    = false
sql_backups_enabled        = true
sql_point_in_time_recovery = false
run_min_instances          = 0
run_max_instances          = 2
run_deletion_protection    = false

viewer_members = ["group:gcp-devops@comm-it.cloud"]
