terraform {
  required_version = ">= 1.9"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.10"
    }
  }

  # No remote backend configured yet — state is local by default, which is fine for
  # a single operator but unsafe for a team (state holds no secrets itself, Vault
  # policies/auth config aren't sensitive, but losing it means re-importing everything
  # by hand). GitLab already hosts this repo, so its built-in Terraform state backend
  # is the natural fit once this repo has a project path:
  #
  # backend "http" {
  #   address        = "https://gitlab.edusystems.online/api/v4/projects/<PROJECT_ID>/terraform/state/vault"
  #   lock_address   = "https://gitlab.edusystems.online/api/v4/projects/<PROJECT_ID>/terraform/state/vault/lock"
  #   unlock_address = "https://gitlab.edusystems.online/api/v4/projects/<PROJECT_ID>/terraform/state/vault/lock"
  #   lock_method    = "POST"
  #   unlock_method  = "DELETE"
  #   retry_wait_min = 5
  # }
  # (username/password come from TF_HTTP_USERNAME / TF_HTTP_PASSWORD env vars — a
  # GitLab CI job token or personal access token with `api` scope)
}
