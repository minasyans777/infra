#!/usr/bin/env python3
"""Run bootstrap or Longhorn over SSH; keep credentials out of Terraform."""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--longhorn-only", action="store_true")
    args = parser.parse_args()
    config = json.loads(os.environ["CLUSTER_CONFIG"])
    scripts = Path(__file__).resolve().parent
    control = config["control_plane"]
    nodes = [control, *config["workers"]]

    def remote(node, command, stdin=None, capture=False):
        ssh = ["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no",
               "-o", "ConnectTimeout=30", "-i", config["ssh_private_key_file"],
               "-p", str(config["ssh_port"]),
               f'{config["ssh_user"]}@{node["ip"]}']
        if config["ssh_user"] != "root":
            command = ["sudo", "-n", *command]
        return subprocess.run([*ssh, shlex.join(command)], input=stdin,
                              text=True, check=True, capture_output=capture)

    def script(node, filename, args):
        print(f'{node["name"]}: {filename}', flush=True)
        remote(node, ["bash", "-s", "--", *args], (scripts / filename).read_text())

    if args.longhorn_only:
        script(control, "install-longhorn.sh", [config["longhorn_chart_version"]])
        return

    for node in nodes:
        script(node, "prepare-node.sh", [node["ip"], node["name"], config["kubernetes_version"]])
    script(control, "bootstrap-control-plane.sh",
           [control["ip"], control["name"], config["pod_network_cidr"],
            config["cilium_version"], config["ssh_user"]])
    for worker in config["workers"]:
        joined = remote(worker, ["bash", "-c", "test -f /etc/kubernetes/kubelet.conf && echo joined || true"], capture=True)
        if joined.stdout.strip() == "joined":
            print(f'{worker["name"]}: already joined', flush=True)
            continue
        print(f'{worker["name"]}: joining cluster', flush=True)
        # Capture token output; never put the credential in an SSH argv or log.
        result = remote(control, ["kubeadm", "token", "create", "--ttl", "15m", "--print-join-command"], capture=True)
        join = shlex.split(result.stdout.strip())
        if join[:2] != ["kubeadm", "join"]:
            raise RuntimeError("Control plane did not return a kubeadm join command")
        token = join[join.index("--token") + 1]
        try:
            remote(worker, ["bash", "-s"], shlex.join([*join, "--node-name", worker["name"]]) + "\n", capture=True)
        except subprocess.CalledProcessError as error:
            print((error.stdout + error.stderr).replace(token, "[REDACTED]"), file=sys.stderr)
            raise RuntimeError(f'{worker["name"]}: kubeadm join failed') from None
    script(control, "verify-cluster.sh", [node["name"] for node in nodes])


if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, RuntimeError) as error:
        # CalledProcessError for SSH contains no join credentials in argv.
        print(f"Bootstrap failed: {error}", file=sys.stderr)
        sys.exit(1)
