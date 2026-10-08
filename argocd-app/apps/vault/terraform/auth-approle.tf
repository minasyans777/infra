resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

resource "vault_approle_auth_backend_role" "ci_deploy_policy" {
  backend        = vault_auth_backend.approle.path
  role_name      = "ci-deploy-policy"
  token_policies = [vault_policy.ci_deploy_policy.name]
  token_ttl      = 900
  token_max_ttl  = 3600
}
