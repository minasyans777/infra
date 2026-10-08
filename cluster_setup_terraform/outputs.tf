output "control_plane_address" {
  value = var.control_plane.ip
}

output "nodes" {
  value = local.nodes
}

output "remote_kubeconfig_path" {
  description = "Administrative credentials on the control-plane host; retrieve explicitly using the README instructions."
  value       = "/etc/kubernetes/admin.conf"
}
