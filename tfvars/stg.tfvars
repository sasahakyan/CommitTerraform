environment              = "stg"
project_id               = "REPLACED_BY_BOOTSTRAP"
deployer_service_account = "REPLACED_BY_BOOTSTRAP"
region                   = "europe-west1"
candidate_name           = "Sahak Sahakyan"

# Staging mirrors production shape at a smaller size.
sql_tier                   = "db-custom-1-3840"
sql_availability_type      = "ZONAL"
sql_deletion_protection    = true
sql_backups_enabled        = true
sql_point_in_time_recovery = true
run_min_instances          = 0
run_max_instances          = 5
run_deletion_protection    = true

viewer_members = []
