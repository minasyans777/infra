# Architecture

## Repository layout

```
tls/                          cert-manager manifests: private CA + the server certificate
                               every Vault pod mounts (applied first, before Helm — see README.md)

helmfile.yaml                 Deploys hashicorp/vault via the Helm chart
helm/values/vault.yaml         Raft HA, TLS-only, Shamir-sealed, 1 replica today, written for a
                               3-node target — see comments inline and scaling-to-ha.md

terraform/                    Everything inside Vault, as code, applied after the cluster is
                               installed, initialized and unsealed (see documentation/bootstrap-and-unseal.md)
  kv.tf                        KV v2 engine at secret/ (tenant secrets)
  auth-kubernetes.tf           Kubernetes auth method + roles for ESO and moodle-token-writer
  auth-approle.tf              AppRole auth method + role for registration repo's CI (see README.md)
  policies/*.hcl.tpl           One HCL policy per consumer

documentation/                This directory
```

## How it fits together

```
   tls/*.yaml (cert-manager)
          │  mints a private CA + one server certificate (SANs cover all 3 pods)
          ▼
   helmfile apply  (hashicorp/vault chart)
          │  StatefulSet, 1 replica today (3 once the 2 worker nodes exist — see
          │  documentation/scaling-to-ha.md), each with its own PVC, TLS-only listener
          ▼
   sealed, uninitialized Vault pod(s)
          │  operator runs `vault operator init` + `vault operator unseal` per pod
          │  (documentation/bootstrap-and-unseal.md) — this is the one deliberately
          │  manual step; there's no cloud KMS account for this cluster to auto-unseal with
          ▼
   1 unsealed Raft cluster (vault-0 alone today; leader + vault-1/vault-2 followers after scaling)
          │  terraform apply, authenticated with the initial root token
          ▼
   KV v2 engine + Kubernetes auth roles + policies, all as code
          │
          ├──▶ External Secrets Operator (ClusterSecretStore "vault-backend")
          │    reads <org>/secrets, <org>/moodle for every tenant — see gitops repo
          │
          ├──▶ moodle-token-job / moodle-init-job (per-tenant, in-cluster)
          │    patch <org>/secrets with the Moodle webservice token — see gitops repo
          │
          └──▶ registration repo's CI (deploy-hello.sh / add-moodle.sh / provision-shared-env.sh)
               writes <org>/secrets, <org>/moodle when provisioning a tenant
```

This repo only owns what's *inside* Vault and the cluster resources needed to run
it. It doesn't touch the `gitops` or `registration` repos — those already assume a
Vault matching this shape exists (`vault.clusterSecretStoreName`, `vault.addr`,
`vault.kvMountPath`, `vault.k8sAuthRole` in `gitops/helm/edusystems-org/values.yaml`),
which is why the mount path, auth role names and policies here were chosen to match
what's already referenced there rather than invented fresh.

## Why Shamir instead of auto-unseal

The task this repo was built for asked for KMS/HSM auto-unseal specifically to avoid
manual unsealing. That needs a cloud KMS (AWS/GCP/Azure) or an HSM — this cluster has
neither (no cloud account is used anywhere else in these repos; DNS/TLS/ingress are
all self-managed). Shipping a `seal "awskms" {}` block pointing at a KMS key that
doesn't exist wouldn't reduce toil, it would just fail to start. See
[bootstrap-and-unseal.md](bootstrap-and-unseal.md) for the manual process this uses
instead, and `helm/values/vault.yaml` for how to switch to a real auto-unseal seal
later if a cloud KMS account is ever added.

See also: [bootstrap-and-unseal.md](bootstrap-and-unseal.md), [tls.md](tls.md), [scaling-to-ha.md](scaling-to-ha.md).
