#!/usr/bin/env bash
# Creates the dev/stg/prd GitHub Environments on both consuming repositories
# and pushes the per-environment variables produced by the bootstrap stack.
# stg and prd require a reviewer before any job bound to them can run.
#
#   scripts/setup-github-environments.sh dev
set -euo pipefail

ENV="${1:?usage: scripts/setup-github-environments.sh <dev|stg|prd>}"
OWNER="${GITHUB_OWNER:-sasahakyan}"
TF_REPO="${OWNER}/CommitTerraform"
SVC_REPO="${OWNER}/commitService"
cd "$(dirname "$0")/../bootstrap"

out() { terraform output -raw "$1"; }
PROJECT_ID="$(out project_id)"
WIF_PROVIDER="$(out wif_provider)"
TF_SA="$(out terraform_ci_service_account)"
DEPLOY_SA="$(out app_deploy_service_account)"
REGION="$(grep -E '^region' "tfvars/${ENV}.tfvars" | sed -E 's/.*= *"([^"]+)".*/\1/')"
REVIEWER_ID="$(gh api users/"$OWNER" --jq .id)"

ensure_env() {
  local repo="$1" env="$2"
  if [ "$env" = "dev" ]; then
    gh api -X PUT "repos/${repo}/environments/${env}" --input - <<<'{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}' >/dev/null
    gh api -X POST "repos/${repo}/environments/${env}/deployment-branch-policies" -f name=main -f type=branch >/dev/null 2>&1 || true
  else
    gh api -X PUT "repos/${repo}/environments/${env}" --input - <<EOF_JSON >/dev/null
{"reviewers":[{"type":"User","id":${REVIEWER_ID}}],"prevent_self_review":false,
 "deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}
EOF_JSON
    gh api -X POST "repos/${repo}/environments/${env}/deployment-branch-policies" -f name=main -f type=branch >/dev/null 2>&1 || true
  fi
}

setvar() { gh variable set "$2" -R "$1" -e "$ENV" -b "$3"; }

for repo in "$TF_REPO" "$SVC_REPO"; do
  ensure_env "$repo" "$ENV"
  setvar "$repo" WIF_PROVIDER "$WIF_PROVIDER"
done
setvar "$TF_REPO"  GCP_SERVICE_ACCOUNT "$TF_SA"
setvar "$SVC_REPO" GCP_SERVICE_ACCOUNT "$DEPLOY_SA"
setvar "$SVC_REPO" GCP_PROJECT_ID "$PROJECT_ID"
setvar "$SVC_REPO" GCP_REGION "$REGION"

echo "GitHub environment '${ENV}' configured on ${TF_REPO} and ${SVC_REPO}."
echo "After the environment stack is applied, set IMAGE_REPOSITORY, CLOUD_RUN_SERVICE and MIGRATION_JOB"
echo "on ${SVC_REPO} from the stack output github_service_variables."
