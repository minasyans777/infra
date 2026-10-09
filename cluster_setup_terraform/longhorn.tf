resource "terraform_data" "longhorn" {
  triggers_replace = {
    cluster       = terraform_data.cluster.id
    chart_version = var.longhorn_chart_version
    script        = filesha256("${path.module}/scripts/install-longhorn.sh")
  }

  provisioner "local-exec" {
    working_dir = path.module
    command     = "python3 scripts/bootstrap.py --longhorn-only"
    environment = {
      CLUSTER_CONFIG = jsonencode(merge(local.configuration, {
        longhorn_chart_version = var.longhorn_chart_version
      }))
    }
  }
}
