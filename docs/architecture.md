# Architecture

```mermaid
flowchart LR
  subgraph GitHub
    TPL[commitTemplates<br/>modules + reusable workflows]
    TF[CommitTerraform<br/>bootstrap + env stack]
    SVC[commitService<br/>FastAPI + Alembic]
  end

  subgraph GCP["Project meridian-dev-26aa (europe-west1)"]
    WIF[Workload Identity Pool<br/>github / github-oidc]
    SA1[terraform-ci SA]
    SA2[app-deploy SA]
    STATE[(GCS tfstate bucket)]
    AR[Artifact Registry<br/>meridian-dev-images]
    subgraph VPC["meridian-dev-vpc 10.10.0.0/24"]
      RUN[Cloud Run v2<br/>meridian-dev-api<br/>Direct VPC egress]
      JOB[Cloud Run Job<br/>meridian-dev-api-migrate]
    end
    PSA[Private Service Access<br/>peering range /20]
    SQL[(Cloud SQL PostgreSQL 16<br/>private IP only, TLS only)]
    SM[Secret Manager<br/>db-password<br/>third-party-api-token<br/>regional replica]
    RSA[api-runtime SA]
  end

  TF -- OIDC token --> WIF --> SA1 --> STATE
  SA1 -- terraform apply --> VPC & SQL & SM & AR & RUN & JOB
  SVC -- OIDC token --> WIF --> SA2 -- push image --> AR
  SA2 -- roll revision / run job --> RUN & JOB
  RUN -- private IP :5432 --> PSA --> SQL
  JOB -- alembic upgrade head --> PSA
  RUN -- accessSecretVersion --> SM
  RUN -. runs as .-> RSA
  Internet((Internet)) -- GET /health --> RUN
```

## Request path for `/health`

1. Cloud Run receives the request on its public HTTPS endpoint.
2. The handler opens a TLS connection to the Cloud SQL private IP through Direct VPC egress and runs `SELECT 1`.
3. The handler calls Secret Manager `accessSecretVersion` for the third-party token as the runtime service account.
4. Both results, the baked-in commit SHA, the region and the candidate name are returned. Any failure yields HTTP 503 with the reason in place of `ok`.

## Trust boundaries

| Identity | Can | Cannot |
|---|---|---|
| `terraform-ci` (from CommitTerraform only) | manage network, SQL, secrets, Run, AR, IAM in the project | create keys, read state of other envs, act outside the project |
| `app-deploy` (from commitService only) | push to AR, update Run service and job image, act as `api-runtime` | change network, IAM, secrets, create resources |
| `api-runtime` | read its two secrets | anything else; no Cloud SQL IAM role, access is by network path plus password |
| Reviewers | `roles/viewer` | read secret payloads, change anything |
