#!/usr/bin/env bash
set -euo pipefail
node_ip=$1
node_name=$2
kubernetes_version=$3
# Apply before package downloads and persist across reboots.
#cat > /etc/sysctl.d/disable-ipv6.conf <<'IPV6'
#net.ipv6.conf.all.disable_ipv6 = 1
#net.ipv6.conf.default.disable_ipv6 = 1
#IPV6
#chmod 0644 /etc/sysctl.d/disable-ipv6.conf
#sysctl -p /etc/sysctl.d/disable-ipv6.conf
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg open-iscsi containerd python3
systemctl enable --now iscsid
swapoff -a
sed -i -E '/^[[:space:]]*#/! s/^(.*[[:space:]]swap[[:space:]].*)$/# \1/' /etc/fstab
modprobe overlay
modprobe br_netfilter
printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/k8s.conf
cat > /etc/sysctl.d/k8s.conf <<'SYSCTL'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
SYSCTL
sysctl -p /etc/sysctl.d/k8s.conf
install -d -m 0755 /etc/containerd /etc/apt/keyrings
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/g' > "$scratch/containerd.toml"
if ! cmp -s "$scratch/containerd.toml" /etc/containerd/config.toml; then
  install -m 0644 "$scratch/containerd.toml" /etc/containerd/config.toml
  systemctl restart containerd
fi
systemctl enable --now containerd
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${kubernetes_version}/deb/Release.key" | gpg --dearmor > "$scratch/kubernetes.gpg"
install -m 0644 "$scratch/kubernetes.gpg" /etc/apt/keyrings/kubernetes-apt-keyring.gpg
printf 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v%s/deb/ /\n' "$kubernetes_version" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
# Held packages stay at their installed versions on rerun.
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
printf 'KUBELET_EXTRA_ARGS=--node-ip=%s --hostname-override=%s\n' "$node_ip" "$node_name" > "$scratch/kubelet"
if ! cmp -s "$scratch/kubelet" /etc/default/kubelet; then
  install -m 0644 "$scratch/kubelet" /etc/default/kubelet
  systemctl restart kubelet
fi
systemctl enable kubelet
