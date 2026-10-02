#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
for attempt in $(seq 1 40); do
  if status=$(kubectl get nodes -o json); then
    if python3 -c '
import json, sys
nodes = json.load(sys.stdin)["items"]
expected = set(sys.argv[1:])
ready = {n["metadata"]["name"] for n in nodes if any(c["type"] == "Ready" and c["status"] == "True" for c in n["status"].get("conditions", []))}
sys.exit(0 if {n["metadata"]["name"] for n in nodes} == expected and ready == expected else 1)
' "$@" <<< "$status"; then
      kubectl get nodes -o wide
      exit 0
    fi
  fi
  sleep 15
done
kubectl get nodes -o wide || true
kubectl -n kube-system get pods -o wide || true
echo 'Timed out waiting for all expected nodes to become Ready.' >&2
exit 1
