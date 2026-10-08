variable "kv_mount_path" {
  description = "KV v2 mount path for tenant secrets. Must match `vault.kvMountPath` in gitops/helm/edusystems-org/values.yaml."
  type        = string
  default     = "secret"
}

variable "kubernetes_host" {
  description = "Kubernetes API server address, as reached from inside a Vault pod."
  type        = string
  default     = "https://kubernetes.default.svc"
}

variable "eso_service_account_name" {
  description = "ServiceAccount the External Secrets Operator's ClusterSecretStore authenticates as."
  type        = string
  default     = "external-secrets"
}

variable "eso_service_account_namespace" {
  description = "Namespace the External Secrets Operator is installed into."
  type        = string
  default     = "external-secrets"
}
