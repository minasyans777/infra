# vault

Infrastructure-as-code for the production Vault instance the `gitops` and
`registration` repos already depend on (`vault.clusterSecretStoreName`,
`vault.addr`, `vault.kvMountPath`, `vault.k8sAuthRole` in
`gitops/helm/edusystems-org/values.yaml`; `VAULT_TOKEN`/`VAULT_BIN` in
`registration/.gitlab-ci.yml`). Previously that instance was set up and configured
by hand; this repo replaces that with:

- **`tls/`** — cert-manager manifests: a private CA and the TLS certificate every
  Vault pod uses (Raft peer traffic and the API are TLS-only).
- **`helmfile.yaml` + `helm/values/vault.yaml`** — Helmfile driving the official
  `hashicorp/vault` Helm chart: Raft HA, one PVC per pod. Currently 1 replica
  (today's single production node); already configured for the 3-node target
  (1 control-plane + 2 workers) — see
  [documentation/scaling-to-ha.md](documentation/scaling-to-ha.md).
- **`terraform/`** — the Vault Terraform provider managing what's *inside* Vault
  once it's up: the KV v2 secrets engine, Kubernetes auth method + roles, an
  AppRole for CI, and the policies behind all of them.

Vault itself is not deployed via ArgoCD/`gitops` — like CNPG and cert-manager, it's
a *cluster prerequisite* that has to exist before the GitOps-managed tenant
workloads (which read secrets from it) can come up at all. See
`gitops/documentation/prerequisites.md`.

## Quick start

New cluster, from zero — see
[documentation/bootstrap-and-unseal.md](documentation/bootstrap-and-unseal.md) for
the full walkthrough (TLS → Helmfile → `vault operator init` → unseal → Terraform).

## Design notes

- **1 node today, 3 later.** The production cluster is a single node right now,
  growing to 1 control-plane + 2 workers. `helm/values/vault.yaml` runs 1 Raft
  replica today and is already written for the 3-node target (retry_join,
  anti-affinity, and a toleration for the control-plane taint are all in place) —
  scaling up later is a couple of value changes and an unseal, not a migration. See
  [documentation/scaling-to-ha.md](documentation/scaling-to-ha.md).
- **No KMS/HSM auto-unseal.** This cluster is self-managed with no cloud account
  (no AWS/GCP/Azure reference anywhere in these repos) — there's no KMS to point
  auto-unseal at. Sealing is Shamir (5 shares, threshold 3), with a documented
  manual unseal process instead. See
  [documentation/architecture.md](documentation/architecture.md#why-shamir-instead-of-auto-unseal).
- **No Ingress.** Vault's API stays ClusterIP-only, reached via `kubectl
  port-forward` — the same access pattern `registration`'s CI already uses today.
  Especially worth keeping given there's no KMS auto-unseal: a sealed, internet-facing
  Vault is a worse failure mode than an internet-facing unsealed one.
- **Private CA, not the existing `letsencrypt-prod` issuer.** See
  [documentation/tls.md](documentation/tls.md).
- **Fresh start, not a migration.** The old `vault-active` instance held no data
  worth preserving (per the person who commissioned this repo) — this repo doesn't
  attempt to import anything from it.

## Follow-ups (not done here)

- **`registration`'s CI now logs in via AppRole in code, but isn't switched over
  live yet.** `deploy-hello.sh`, `add-moodle.sh`, `provision-shared-env.sh` all now
  `require_env VAULT_ROLE_ID`/`VAULT_SECRET_ID` and log in via
  `auth/approle/login` instead of expecting a pre-set `VAULT_TOKEN` (matches
  `terraform/auth-approle.tf`'s `ci-provisioner` role). What's still needed,
  against a live, authenticated Vault:
  1. `vault read auth/approle/role/ci-provisioner/role-id` — not secret, this is
     the `VAULT_ROLE_ID` value.
  2. `vault write -f auth/approle/role/ci-provisioner/secret-id` — *is* secret,
     shown once, this is the `VAULT_SECRET_ID` value.
  3. Set both as GitLab CI/CD variables (masked + protected) on the
     `registration` project, then remove the old `VAULT_TOKEN` variable.
- `moodle-token-writer`'s Kubernetes auth role binds `bound_service_account_names =
  ["*"]` because tenant orgs (and their `<org>-moodle-token-writer` ServiceAccounts)
  aren't known ahead of time — see the comment in `terraform/auth-kubernetes.tf`.
  Tightening this to one role per org would mean `registration`'s CI managing a
  Terraform resource per tenant at provisioning time.
- No remote Terraform state backend configured yet (see `terraform/versions.tf` for
  a commented-out GitLab-managed option) — state is local, fine for one operator,
  not for a team.
- `deploy-hello.sh` and `provision-shared-env.sh` use `VAULT_SKIP_VERIFY=true`
  rather than trusting the CA properly — written before `tls/20-server-certificate.yaml`
  had `127.0.0.1`/`localhost` SANs added specifically for this port-forward case, so
  it's no longer strictly necessary. Low priority (skip-verify here only weakens an
  already-localhost-only, kubeconfig-authenticated hop), but `VAULT_CACERT` pointed
  at a fetched copy of `vault-ca-key-pair`'s `ca.crt` would be more correct.
