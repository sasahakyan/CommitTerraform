# Partial configuration; bucket and prefix are supplied per environment:
#   terraform init -backend-config=backend/dev.hcl
terraform {
  backend "gcs" {}
}
