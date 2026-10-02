#!/usr/bin/env bash
set -euo pipefail
node_ip=$1
node_name=$2
pod_cidr=$3
cilium_version=$4
ssh_user=$5
export KUBECONFIG=/etc/kubernetes/admin.conf
if [[ ! -f "$KUBECONFIG" ]]; then
  kubeadm init --pod-network-cidr="$pod_cidr" --control-plane-endpoint="$node_ip" --apiserver-advertise-address="$node_ip" --node-name="$node_name"
fi
user_home=$(getent passwd "$ssh_user" | cut -d: -f6)
user_group=$(id -gn "$ssh_user")
[[ -n "$user_home" ]]
install -d -m 0755 -o "$ssh_user" -g "$user_group" "$user_home/.kube"
install -m 0600 -o "$ssh_user" -g "$user_group" "$KUBECONFIG" "$user_home/.kube/config"
if ! command -v helm >/dev/null; then
  installer=$(mktemp)
  trap 'rm -f "$installer"' EXIT
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$installer"
  bash "$installer"
fi
helm repo add cilium https://helm.cilium.io/ --force-update
helm repo update cilium
helm upgrade --install cilium cilium/cilium --version "$cilium_version" --namespace kube-system
