resource "vault_mount" "kv" {
  path        = var.kv_mount_path
  type        = "kv"
  options     = { version = "2" }
  description = "Tenant application secrets (see registration and gitops repos)"
}
