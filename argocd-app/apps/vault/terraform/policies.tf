resource "vault_policy" "external_secrets" {
  name   = "external-secrets"
  policy = templatefile("${path.module}/policies/external-secrets.hcl.tpl", { kv_mount_path = var.kv_mount_path })
}

resource "vault_policy" "moodle_token_writer" {
  name   = "moodle-token-writer"
  policy = templatefile("${path.module}/policies/moodle-token-writer.hcl.tpl", { kv_mount_path = var.kv_mount_path })
}

resource "vault_policy" "ci_deploy_policy" {
  name   = "ci-deploy-policy"
  policy = templatefile("${path.module}/policies/ci-deploy-policy.hcl.tpl", { kv_mount_path = var.kv_mount_path })
}

resource "vault_policy" "garage_key_writer" {
  name   = "garage-key-writer"
  policy = templatefile("${path.module}/policies/garage-key-writer.hcl.tpl", { kv_mount_path = var.kv_mount_path })
}

resource "vault_policy" "vault_snapshot" {
  name   = "vault-snapshot"
  policy = file("${path.module}/policies/vault-snapshot.hcl")
}
