locals {
  nodes = concat([var.control_plane], var.workers)
  configuration = {
    control_plane        = var.control_plane
    workers              = var.workers
    ssh_user             = var.ssh_user
    ssh_private_key_file = pathexpand(var.ssh_private_key_file)
    ssh_port             = var.ssh_port
    kubernetes_version   = var.kubernetes_version
    cilium_version       = var.cilium_version
    pod_network_cidr     = var.pod_network_cidr
  }
}

# These records manage bootstrap execution on existing servers, not their lifetime.
resource "terraform_data" "cluster" {
  triggers_replace = {
    configuration = sha256(jsonencode(local.configuration))
    scripts = sha256(join("", [
      for script in sort(tolist(fileset(path.module, "scripts/*"))) : filesha256("${path.module}/${script}")
    ]))
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for node in local.nodes : can(cidrnetmask("${node.ip}/32")) && can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", node.name)) && length(node.name) <= 63
      ])
      error_message = "Fill in every server's IPv4 address and use valid Kubernetes node names before planning."
    }
    precondition {
      condition     = length(distinct([for node in local.nodes : node.ip])) == length(local.nodes) && length(distinct([for node in local.nodes : node.name])) == length(local.nodes)
      error_message = "Every server must have a unique IP and node name."
    }
  }

  provisioner "local-exec" {
    working_dir = path.module
    command     = "python3 scripts/bootstrap.py"
    environment = { CLUSTER_CONFIG = jsonencode(local.configuration) }
  }
}
