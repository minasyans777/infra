#!/usr/bin/env bash
set -euo pipefail
longhorn_version=$1
export KUBECONFIG=/etc/kubernetes/admin.conf

helm repo add longhorn https://charts.longhorn.io --force-update
helm repo update longhorn
helm upgrade --install longhorn longhorn/longhorn \
  --version "$longhorn_version" \
  --namespace longhorn-system --create-namespace \
  --set persistence.defaultClass=true \
  --set persistence.defaultClassReplicaCount=2 \
  --timeout 900s --wait
