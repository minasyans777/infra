# Used by the "moodle-token-writer" k8s-auth role, which every "<org>-moodle-token-writer"
# ServiceAccount (one per tenant with Moodle enabled) authenticates as — see
# gitops' moodle-token-job.yaml / moodle-init-job.yaml. It only ever patches an
# already-existing <org>/secrets entry to add the Moodle webservice token, and reads
# <org>/moodle for install status.
path "${kv_mount_path}/data/+/secrets" {
  capabilities = ["read", "update"]
}

path "${kv_mount_path}/data/+/moodle" {
  capabilities = ["read"]
}
