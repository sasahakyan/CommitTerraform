# Meridian Payments on Google Cloud: proof of concept

One API service on Cloud Run talking to Cloud SQL for PostgreSQL over a private
network, secrets in Secret Manager, everything provisioned with Terraform and
deployed through keyless GitHub Actions. Three repositories:

| Repo | Role |
|---|---|
| **[CommitTerraform](https://github.com/sasahakyan/CommitTerraform)** (this one) | Infrastructure. `bootstrap/` per environment, one env stack with `tfvars/{dev,stg,prd}.tfvars` |
| [commitTemplates](https://github.com/sasahakyan/commitTemplates) | Terraform modules and reusable workflows, consumed by tag |
| [commitService](https://github.com/sasahakyan/commitService) | FastAPI service, Alembic migrations, build and deploy pipeline |

Live: **https://meridian-dev-api-5vy4wvjs6q-ew.a.run.app/health** · Project `meridian-dev-26aa` · Region `europe-west1` · Diagram in [docs/architecture.md](docs/architecture.md)

## Architecture in one paragraph

A dedicated project per environment, created without a default network. One
custom VPC with a single subnet and a Private Service Access range peered to
Google's producer network. Cloud SQL has no public IP and refuses non-TLS
connections. Cloud Run reaches it through Direct VPC egress; only private
ranges route into the VPC, Google APIs go over the backbone. The service runs
as its own service account whose only permissions are reading its two secrets.
Secrets are replicated to the workload region only. Migrations run as a Cloud
Run Job with the same image, identity and network path before each deploy.

## Decisions

- **Cloud Run over GKE or Compute Engine.** One stateless HTTP service with an unknown, probably bursty load profile. Cloud Run gives scale to zero, per-revision rollout, built-in TLS and identity, and no nodes to patch. GKE only pays off with many services or sidecar-heavy workloads; a VM would put OS patching back on a payments team. Direct VPC egress removes the Serverless VPC Access connector, which costs money while idle and is a second thing to size.
- **Custom VPC, not the default.** The brief's reasoning was wrong: Cloud SQL private IP needs a peering, not co-location. The default VPC brings open SSH/RDP rules and subnets in every region, which an auditor will flag.
- **Workload Identity Federation, not a JSON key.** Short-lived tokens, bound to one repository each, nothing to rotate or leak. Two identities: `terraform-ci` with curated admin roles, `app-deploy` that can only push images and roll revisions.
- **Terraform owns the service, the pipeline owns the image tag.** `ignore_changes` on the image, SHA baked into the image at build so there is no environment drift.
- **One code base, three tfvars.** PRs plan every active environment and post the plan. Merge applies dev. stg and prd apply only by manual dispatch behind a required reviewer. The exact same mechanism deploys the service.
- **Database access for developers is not from laptops.** Migrations run in the pipeline. Ad hoc access would go through an IAP bastion, designed but not built. See ASSUMPTIONS.md.

## How to run

```sh
# once per environment, from a laptop with projectCreator + billing.user
gcloud auth application-default login
scripts/bootstrap.sh dev            # project, APIs, state bucket, WIF, CI identities
scripts/setup-github-environments.sh dev
# copy project_id / deployer SA / bucket from the outputs into tfvars/dev.tfvars and backend/dev.hcl
git commit && git push              # CI plans on PR, applies dev on merge
# then set IMAGE_REPOSITORY, CLOUD_RUN_SERVICE, MIGRATION_JOB on commitService (output github_service_variables)
# and push commitService: build -> migrate -> deploy -> smoke test /health
```

Local plan: `terraform init -backend-config=backend/dev.hcl && terraform plan -var-file=tfvars/dev.tfvars`.
Teardown: `terraform destroy -var-file=tfvars/dev.tfvars`, then `terraform -chdir=bootstrap destroy -var-file=tfvars/dev.tfvars`.

## Time spent

TIME_PLACEHOLDER

## With more time

- IAP bastion or Cloud SQL Auth Proxy with IAM database authentication for developer access, with `cloudsql.instances.login` per developer instead of a shared password.
- Customer-managed encryption keys on Cloud SQL and Secret Manager, and organisation policies (`sql.restrictPublicIp`, `iam.disableServiceAccountKeyCreation`, `compute.skipDefaultNetworkCreation`) enforced at the folder so the choices here cannot be undone by hand.
- Global external load balancer with Cloud Armor in front of Cloud Run, ingress set to internal-and-LB only. That is also the hook for a future US region: a second stack in `us-central1` behind the same LB, with data residency decided per customer, not per request.
- Uptime check and alerting on `/health`, SLO on latency, budget alert on the project.
- Terraform tests for the modules, Checkov or similar in the PR gate, and a `stg` bootstrap so the promotion path is exercised end to end.
