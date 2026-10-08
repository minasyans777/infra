resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "this" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = var.kubernetes_host
}

resource "vault_kubernetes_auth_backend_role" "external_secrets" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "external-secrets"
  bound_service_account_names      = [var.eso_service_account_name]
  bound_service_account_namespaces = [var.eso_service_account_namespace]
  token_policies                   = [vault_policy.external_secrets.name]
  token_ttl                        = 3600
  token_max_ttl                    = 3600
}

resource "vault_kubernetes_auth_backend_role" "moodle_token_writer" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "moodle-token-writer"
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces = ["*"]
  token_policies                   = [vault_policy.moodle_token_writer.name]
  token_ttl                        = 300
  token_max_ttl                    = 900
}

resource "vault_kubernetes_auth_backend_role" "garage_key_writer" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "garage-key-writer"
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces = ["*"]
  token_policies                   = [vault_policy.garage_key_writer.name]
  token_ttl                        = 300
  token_max_ttl                    = 900
}
