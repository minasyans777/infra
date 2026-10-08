control_plane = { name = "cp1", ip = "10.10.9.241" }
workers = [
  { name = "worker1", ip = "10.10.9.242" },
  { name = "worker2", ip = "10.10.9.243" }
]
ssh_user             = "root"
ssh_private_key_file = "~/.ssh/sam-k8s"
ssh_port             = 22
kubernetes_version   = "1.36"
cilium_version       = "1.17.1"
pod_network_cidr     = "10.244.0.0/16"
