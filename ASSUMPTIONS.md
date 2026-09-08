# Assumptions

Meridian did not reply to the clarification email before the build started, so
every open point below was resolved on the default I had already stated in that
email. Each entry records the decision and the reasoning; where the answer
would change the design, it says what would change.

## Pushed back and built differently

1. **Default VPC.** Not used. Cloud SQL private IP works over Private Service Access from any VPC; the default network's auto subnets in every region and its open SSH/RDP rules are a liability for a regulated workload. The project is created with `auto_create_network = false`, so the default VPC never exists. *If Meridian insists:* it is a one-line change to import the default network, and I would record the audit risk in writing.
2. **Service account JSON key in GitHub secrets.** Not created. Workload Identity Federation issues short-lived tokens bound to one repository each. No long-lived credential exists in either GitHub or the repository. *If there is a hard constraint* (an org tool that needs a key), the same service accounts can be used; only the auth step in the reusable workflow changes.
3. **Developers running migrations from laptops.** Conflicts with "not reachable from the internet under any circumstances". Migrations run as a Cloud Run Job inside the VPC, executed by the pipeline before each deploy. Ad hoc access would be an IAP-forwarded bastion with no public IP, or Cloud SQL Auth Proxy with IAM database authentication; both are designed, neither built in the five hours.

## Decided without an answer

4. **Region: europe-west1.** Customers are in Lithuania and Germany; no data-residency statement was available. Backups are pinned to the `eu` multi-region and Secret Manager replication to the region. *If Germany-only were required:* `europe-west3`, one tfvars change.
5. **US customers later.** Treated as a second deployment (another env stack in a US region behind a global load balancer), not as multi-region data in this stack. Nothing here is region-locked except the tfvars.
6. **The environment is disposable.** Three-week PoC, so dev has no deletion protection, PITR off, smallest tier, and the project deletion policy is `DELETE`. The prd tfvars show what production would carry: regional HA, PITR, deletion protection, warm instance.
7. **The API is public.** Only because the exercise requires a public `/health`. The `run_public` and ingress variables exist so production can sit behind an internal load balancer.
8. **Third-party token.** Meridian owns it. Terraform creates the secret with a random placeholder so the application path can be proven; the real value is added as a new version out of band and never passes through code or state.
9. **No existing landing zone.** Deployed as a new project directly under the organisation with no folder or org policies. In a real engagement the `bootstrap/` stack would target Meridian's folder and their policies would already forbid keys and public SQL.
10. **Scale.** Unknown. Cloud Run min 0 / max 2 in dev; prd tfvars use min 1 / max 20 and a dedicated-core database. Query Insights is on everywhere so the numbers can be learned.
11. **Database credentials.** A generated 32-character password stored in Secret Manager and injected as an environment variable by Cloud Run. IAM database authentication was considered and deferred: it needs the Cloud SQL Auth Proxy or the Python connector in the container, which is the right production step but more moving parts for a PoC.
12. **Shared project vs dedicated.** The available project already hosted another application. A dedicated project keeps the reviewers' `roles/viewer` grant, the billing view and the teardown clean, and matches what a payments customer would expect.

## Exercise mechanics

13. `db` and `secret` in `/health` run on every request: a fresh Postgres connection with `SELECT 1`, and a live `accessSecretVersion` call. Results are not cached and the response carries `Cache-Control: no-store`.
14. `commit` is the short SHA baked into the image at build time by the reusable build workflow, so it cannot drift from what the pipeline deployed.
15. The dev database password was rotated once during the build after the first migration execution printed it into Cloud Logging. The rotation went through a pull request and a CI apply, which is the mechanism production would use. The leaked value is invalid; the log entry itself cannot be deleted individually and expires with the 30-day default retention.
16. The Cloud Billing API had to be enabled on the pre-existing quota project by hand for the bootstrap to check billing permissions. That is the only console/gcloud action outside Terraform, and it touched no Meridian resource.

## Questions I would still ask Meridian

- Which regulator's residency rules apply (Bank of Lithuania, BaFin) and do they constrain backup location or support access?
- Is there an existing VPN or Interconnect from the office into AWS today, and should its GCP equivalent be part of the target?
- Who owns the third-party token, how often does it rotate, and does the provider allowlist source IPs (which would force a static egress IP through Cloud NAT)?
- Availability target and expected requests per second, so HA and min instances are a decision rather than a guess.
- Is there a GCP organisation and landing zone already, with folders, org policies and a shared VPC, that this should slot into?
