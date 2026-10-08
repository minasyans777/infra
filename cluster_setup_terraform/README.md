# Stage 1: Kubernetes bootstrap

This Terraform root replaces the Ansible stage-1 workflow on existing Ubuntu
24.04 servers: host prerequisites, containerd, Kubernetes packages, one kubeadm
control plane, Cilium, worker joins, and a final node-readiness check. It does not
create servers or install the stage-2 add-ons.

## Requirements

- Terraform >= 1.5, Python 3, and OpenSSH on the machine running Terraform.
- Existing Ubuntu hosts with unique IPv4 addresses and names. The default layout
  has one control plane and two workers. IP fields are intentionally empty.
- SSH key access as root, or a user with passwordless sudo (`sudo -n`).
- Verified host keys already in the local SSH known_hosts file. Test SSH access
  to each host before applying; host-key checking is mandatory.
- Hosts can download Ubuntu/Kubernetes packages, Helm, Cilium, and container images.
- Hosts can communicate over the ports required by kubeadm and Cilium. This
  configuration does not manage firewalls or routes. The pod CIDR must not overlap
  the host network or other routed networks.

The versions default to the existing Ansible values (Kubernetes track `1.36`,
Cilium `1.17.1`). Confirm that the track is published and that the selected Cilium
version supports your Kubernetes version before applying. These defaults preserve
configuration parity; they are not a compatibility certification.

## Usage

From this directory:

```bash
cp terraform.tfvars.example terraform.tfvars
# Fill every ip field, check SSH settings, and select compatible versions.
terraform init
terraform plan
terraform apply
```

Planning fails with a clear error while IP fields are empty. Planning does not
contact servers. Applying changes every configured host: swap is disabled, kernel
and runtime settings are written, packages are installed and held, services are
enabled, and Kubernetes is bootstrapped. Before package downloads, node preparation
disables IPv6 on existing and future interfaces using
`net.ipv6.conf.all.disable_ipv6=1` and
`net.ipv6.conf.default.disable_ipv6=1`. These settings are written to
`/etc/sysctl.d/disable-ipv6.conf` and applied immediately, persisting across reboots.
The script hash change schedules the guarded bootstrap again on the next apply;
review `terraform plan` before applying.

Terraform runs `scripts/bootstrap.py` locally using `local-exec` on a built-in
`terraform_data` resource. The runner sends Bash scripts over SSH, first preparing
all hosts, then initializing the control plane and installing Cilium, then joining
workers, then waiting up to roughly ten minutes for exactly the expected nodes to
be Ready. SSH and package operations add to the total runtime.

The kubelet IP is explicitly pinned to each configured address, and the configured
name is used for Kubernetes node registration. The connecting user's kubeconfig
is installed on the control plane with mode 0600. Helm installation follows the
existing Ansible installer workflow. Cilium uses the same default chart values.

Worker join tokens have a 15-minute TTL and are captured only in the local runner's
memory. They are sent to workers through SSH stdin, not Terraform outputs, state,
or SSH command arguments. Existing workers skip join when their kubelet.conf exists.

## Retrieve kubeconfig

For the default root user, substitute your actual address:

```bash
install -d -m 700 ~/.kube
(umask 077; ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -i ~/.ssh/sam-k8s root@CONTROL_PLANE_IP 'cat /etc/kubernetes/admin.conf' > ~/.kube/cluster-bootstrap.conf)
export KUBECONFIG="$HOME/.kube/cluster-bootstrap.conf"
kubectl get nodes -o wide
```

For a non-root SSH user, use `sudo -n cat /etc/kubernetes/admin.conf` as the remote
command. Adjust key and port to match your configuration. Use a new destination
path to avoid overwriting another cluster's credentials. This file grants cluster
administrator access; keep it private. It is downloaded explicitly rather than
stored in Terraform state. Stage 2, if desired later, is a separate apply in
`../terraform/` with this kubeconfig path.

## Repeat runs, recovery, and limits

Terraform records completion of the entire bootstrap, not individual Linux package
or Kubernetes resources. Configuration and script hashes trigger another run when
changed; unchanged applies do not inspect or repair host drift. A partial failure
fails the apply; the next apply reruns the guarded bootstrap. To repair drift or
repeat readiness checks explicitly:

```bash
terraform apply -replace=terraform_data.cluster
```

Init and join are guarded by their existing Kubernetes configuration files.
Containerd and kubelet restart when their generated configuration changes. Helm
uses upgrade --install. Repeating bootstrap is intended for the same hosts and
cluster; the file guards do not establish ownership of an unrelated existing
cluster. Use fresh hosts for initial deployment.

Installed Kubernetes packages are held. Changing the minor version does not
upgrade an existing cluster; upgrades require a separate kubeadm upgrade procedure.
Changing addresses, names, or pod CIDR also does not migrate an initialized cluster.
Worker removal does not drain or delete its Kubernetes node; the exact-membership
readiness check will fail until that is handled separately. Generated containerd
configuration replaces custom settings, matching the Ansible workflow.

`terraform destroy` only removes the bootstrap record from state. It does not
reset kubeadm, uninstall packages, erase data, or delete servers. No destroy-time
provisioners are configured. Preserve state for predictable rerun behavior; state
contains configuration hashes and public outputs, not private-key contents or
kubeconfig credentials. Keep local tfvars and state uncommitted (the root ignore
rules already cover them).

## Local validation

```bash
terraform fmt -check
terraform init -backend=false
terraform validate
bash -n scripts/prepare-node.sh scripts/bootstrap-control-plane.sh scripts/verify-cluster.sh
```

These checks do not deploy a cluster. A real deployment is required to validate
SSH access, version compatibility, network reachability, and node readiness.
