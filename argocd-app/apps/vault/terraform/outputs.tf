output "kv_mount_path" {
  value = vault_mount.kv.path
}

output "kubernetes_auth_path" {
  value = vault_auth_backend.kubernetes.path
}

output "approle_auth_path" {
  value = vault_auth_backend.approle.path
}

output "ci_deploy_policy_role_name" {
  value       = vault_approle_auth_backend_role.ci_deploy_policy.role_name
  description = "Use with `vault write -f auth/approle/role/<this>/secret-id` — see README.md Follow-ups."
}
