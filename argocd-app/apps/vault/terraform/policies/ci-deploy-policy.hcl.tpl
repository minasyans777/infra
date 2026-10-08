path "${kv_mount_path}/data/*" {
  capabilities = ["create", "read", "update", "list"]
}

path "${kv_mount_path}/metadata/*" {
  capabilities = ["read", "list"]
}
