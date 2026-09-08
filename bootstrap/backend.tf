# Partial configuration: bucket and prefix come from backend/<env>.hcl.
# On the very first run the bucket does not exist yet; scripts/bootstrap.sh
# temporarily overrides this with a local backend and migrates afterwards.
terraform {
  backend "gcs" {}
}
