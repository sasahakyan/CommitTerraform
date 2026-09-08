environment              = "prd"
project_id               = "REPLACED_BY_BOOTSTRAP"
deployer_service_account = "REPLACED_BY_BOOTSTRAP"
region                   = "europe-west1"
candidate_name           = "Sahak Sahakyan"

# Production target: regional HA with automatic failover, PITR, deletion
# protection on everything, at least one warm instance to avoid cold starts.
sql_tier                   = "db-custom-2-7680"
sql_availability_type      = "REGIONAL"
sql_disk_size_gb           = 50
sql_deletion_protection    = true
sql_backups_enabled        = true
sql_point_in_time_recovery = true
run_min_instances          = 1
run_max_instances          = 20
run_deletion_protection    = true

viewer_members = []
