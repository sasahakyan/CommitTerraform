#!/usr/bin/env bash
# One-time bootstrap of an environment: project, APIs, state bucket, WIF, CI
# identities. This is the only Terraform in the repository that is applied
# from a laptop, because the bucket that will hold its state does not exist
# yet. After the first apply the state is migrated into that bucket.
#
#   scripts/bootstrap.sh dev
#
# Requires: gcloud authenticated as a user with projectCreator on the org and
# billing.user on the billing account. Nothing here uses a service account key.
set -euo pipefail

ENV="${1:?usage: scripts/bootstrap.sh <dev|stg|prd>}"
# Optional second argument --auto-approve skips the interactive confirmation.
APPROVE=""
[ "${2:-}" = "--auto-approve" ] && APPROVE="-auto-approve"
cd "$(dirname "$0")/../bootstrap"

BACKEND_FILE="backend/${ENV}.hcl"
VARS_FILE="tfvars/${ENV}.tfvars"
[ -f "$VARS_FILE" ] || { echo "missing $VARS_FILE"; exit 1; }

if [ -f "$BACKEND_FILE" ]; then
  echo "==> ${ENV}: remote state already configured (${BACKEND_FILE}); running a normal apply"
  rm -f backend_override.tf
  terraform init -reconfigure -input=false -backend-config="$BACKEND_FILE"
  terraform apply -input=false $APPROVE -var-file="$VARS_FILE"
  exit 0
fi

echo "==> ${ENV}: first run, using a temporary local backend"
cat > backend_override.tf <<'HCL'
# Temporary. Created by scripts/bootstrap.sh for the first apply and deleted
# before the state is migrated to GCS. Git-ignored.
terraform {
  backend "local" {}
}
HCL

terraform init -reconfigure -input=false
terraform apply -input=false $APPROVE -var-file="$VARS_FILE"

BUCKET="$(terraform output -raw state_bucket)"
printf 'bucket = "%s"\nprefix = "bootstrap/%s"\n' "$BUCKET" "$ENV" > "$BACKEND_FILE"

echo "==> migrating state to gs://${BUCKET}/bootstrap/${ENV}"
rm -f backend_override.tf
terraform init -migrate-state -force-copy -input=false -backend-config="$BACKEND_FILE"
rm -f terraform.tfstate terraform.tfstate.backup

echo
echo "==> done. Commit ${BACKEND_FILE}, then wire the environment stack:"
terraform output -raw next_steps
