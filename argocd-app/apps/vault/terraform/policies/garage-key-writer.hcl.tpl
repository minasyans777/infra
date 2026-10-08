path "${kv_mount_path}/data/+/secrets" {
  capabilities = ["read", "update"]
}

path "${kv_mount_path}/data/+/garage" {
  capabilities = ["read"]
}
