variable "control_plane" {
  description = "Existing Ubuntu control-plane server. Set ip before planning."
  type        = object({ name = string, ip = string })
  default     = { name = "cp1", ip = "" }
}

variable "workers" {
  description = "Existing Ubuntu worker servers. Set every ip before planning."
  type        = list(object({ name = string, ip = string }))
  default = [
    { name = "worker1", ip = "" },
    { name = "worker2", ip = "" }
  ]
}

variable "ssh_user" {
  type    = string
  default = "root"
  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]*$", var.ssh_user))
    error_message = "Use a valid Linux SSH username."
  }
}

variable "ssh_private_key_file" {
  description = "Local SSH key path; key contents are never read into Terraform state."
  type        = string
  default     = "~/.ssh/sam-k8s"
}

variable "ssh_port" {
  type    = number
  default = 22
  validation {
    condition     = var.ssh_port >= 1 && var.ssh_port <= 65535 && floor(var.ssh_port) == var.ssh_port
    error_message = "SSH port must be an integer between 1 and 65535."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes minor APT track; fresh hosts install its available patch. Changes are not an upgrade workflow."
  type        = string
  default     = "1.36"
  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "Use a minor version such as 1.36."
  }
}

variable "cilium_version" {
  type    = string
  default = "1.17.1"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.cilium_version))
    error_message = "Use a Cilium chart version such as 1.17.1."
  }
}

variable "longhorn_chart_version" {
  description = "Longhorn Helm chart version, matching cluster-bootstrap."
  type        = string
  default     = "1.7.2"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.longhorn_chart_version))
    error_message = "Use a Longhorn chart version such as 1.7.2."
  }
}

variable "pod_network_cidr" {
  type    = string
  default = "10.244.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.pod_network_cidr))
    error_message = "Provide a valid IPv4 pod CIDR."
  }
}
