# Read-only, every tenant path. ESO's ClusterSecretStore ("vault-backend" — see
# gitops' vault.clusterSecretStoreName) needs to read <org>/secrets and <org>/moodle
# for any org, and org names aren't known ahead of time, so this is intentionally
# mount-wide rather than per-org.
path "${kv_mount_path}/data/*" {
  capabilities = ["read"]
}

path "${kv_mount_path}/metadata/*" {
  capabilities = ["read", "list"]
}
