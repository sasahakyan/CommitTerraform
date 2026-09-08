# AI log

## 1. Tools

- Claude Code (Claude Fable 5.1) in VS Code, with shell, gcloud, terraform, gh and docker access. Used for everything: reading the brief, drafting the clarification email, writing the Terraform modules, workflows, application, and these documents.
- No other assistants. GitHub Copilot was off.

Working mode: I stated the design decisions up front (three repositories, envs as tfvars only, apply only from CI, WIF, Cloud Run) and had the assistant investigate the account and brief, then ask me structured questions before writing any code. Twelve decisions were taken that way in about fifteen minutes. After that it wrote, I read every file, and the log below is what I changed.

## 2. Rejected or corrected

**Alembic URL through configparser, and a password in the logs.** The generated `alembic/env.py` built the database URL as a string with the URL-encoded password and pushed it into the Alembic config with `set_main_option`. Two problems, one of which only showed in production: configparser treats `%` as interpolation syntax, so a password containing `%7D` crashed the migration job; and the traceback printed the full connection string, database password included, into Cloud Logging, where anyone with `roles/viewer` can read it. Replaced with a SQLAlchemy `URL` object passed directly to `create_engine`, which handles any password and masks it when rendered, added a regression test with awkward characters, and rotated the password through a new `password_rotation` keeper in the module (`v0.1.2`) so rotation is a reviewed tfvars change applied by CI. The old value is invalid; the log line still exists because Cloud Logging does not delete individual entries.

**Runtime identity created inside the Cloud Run module.** The first version of `cloudrun-service` created the runtime service account and the `serviceAccountUser` binding for the deployer itself. That couples compute, IAM and secrets: the secrets module needs the account to grant access, and the module needs the secret IDs, so the graph knots up and the module can't be reused for a second service sharing an identity. I moved the account and the deployer binding to the root stack; the module takes an email.

**`for_each` over a set of IAM members.** Three modules (`state-bucket`, `secrets`, `artifact-registry`) iterated `toset(var.members)`. That validates fine and fails at plan time the moment a member is a service account created in the same apply, which is exactly the bootstrap case. Terraform cannot use unknown values as instance keys. Changed to maps keyed by a static label with the member as the value. Tagged as `v0.1.1`. Not cosmetic: the first bootstrap run died on it.

**Reusing the existing project.** The assistant started from the project I had authenticated against, which already hosts an unrelated live application. Granting Commit `roles/viewer` there would have exposed that application's secrets, service accounts and billing. Also, the brief's "default VPC" instruction becomes moot in a fresh project created with `auto_create_network = false`; in a shared project the default network already exists. Switched to a dedicated project per environment created by a bootstrap stack. It cost roughly twenty minutes and is the single most important architectural change in the submission.

**Dockerfile.** First draft did `pip wheel ... || true` followed by `pip download`, and repeated the dependency list in two places. A silent `|| true` in a build is how you ship an image that installs different versions from what you tested. Replaced with a single `requirements.txt`, one install step, non-root user.

**yamllint `--strict`.** The reusable lint workflow used `--strict`, which promotes warnings to failures, while the shared config deliberately makes line length a warning because workflow files have long expressions. Every consumer would have failed on day one. Removed it and switched to GitHub annotation output.

**Pull request plans blocked by the dev environment's branch policy.** The GitHub Environment for dev was created main-only, like stg and prd. The first pull request plan was rejected in one second ("Branch refs/pull/1/merge is not allowed to deploy to dev"), because the plan job needs the environment's WIF variables. dev is now unrestricted; stg and prd stay main-only with a required reviewer.

Smaller ones, kept out of the count: a `data "google_project"` that was declared and never used (tflint caught it), a docker login pointed at the full repository path instead of the registry host, and reading Terraform outputs from a remote backend before credentials were exported, which silently wrote empty strings into tfvars.

## 3. Caught by the AI that I would have missed

- The **Cloud Run startup probe** was going to be `/health`. The assistant pointed out that a probe which depends on Cloud SQL and Secret Manager turns any downstream blip into a service that cannot start a new instance. The probe now hits `/`, which touches nothing.
- **Secret Manager replication**: `automatic` copies secret material to Google-chosen locations worldwide. For an EU payments company that is a residency finding waiting to happen. Replication is user-managed and pinned to the workload region.
- Cloud SQL **reserves a deleted instance name for about a week**. A random suffix on the instance name means a destroy/apply cycle during the review does not fail on a name collision.

## 4. Most useful prompt

Quoted verbatim:

> check PDF in commitService there is writen all requirements
> as you can see we have 3 repos
> - commitTemplates This is for reusable CI/CD workflows and also Terraform generic modules which we are going to use. Here must be github actions pipeline which will run yamllint during open PR and validate that yaml syntax is correct before merge
> - commitTerraform This is Terraform repo here we must separate dev, stg, prd only tfvars and code must be one, we apply only thourh CI/CD pipelines in PR we only run terraform validate and terraform plan and only after apply we can run terraform apply, the logic is following if I select prod dev, stg, prg must be applied depends on env
> - commitService This must be fastAPI python API service which is written in PDF we must have 3 different envs again deploy goes through githib workflows build --> dev --> stg --> prd but now we only need dev, stg and prd let be just temaplte we are not deploying them
> Service must run in Cloud Run, gcloud CLI is authenticated there is proofLeans project use it. Before starting do deep investigated deeply check PDF ask all clarifying questions

It worked because it fixed the shape of the solution and the rules (one code base, tfvars per env, CI-only apply, WIF) and then forced a question round before any code. Everything after that was execution against decisions I had already made.

## 5. Proportion generated

About 90% of the code and 80% of the prose was produced by the assistant. Every file was read before commit. The design decisions, the pushbacks to the customer, the choice of what to build and what to document only, and the corrections above are mine.
