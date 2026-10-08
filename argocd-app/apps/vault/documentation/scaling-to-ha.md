# Scaling from 1 node to 3-node HA

Today this runs as a single-node Raft cluster (`server.ha.replicas: 1` in
`helm/values/vault.yaml`) — that's a real, self-contained Vault deployment, not a
degraded/temporary hack, it just has zero fault tolerance (the node dies, Vault is
down until it's back). The values file is already written for the eventual 3-node
target (1 control-plane + 2 workers), so growing into it is a small, well-understood
operation, not a migration — Raft supports adding voters online.

## Why this topology needs a decision most 3-node clusters don't

With exactly 3 machines and one of them being the control-plane, there's no room to
reserve it exclusively for control-plane duties and still get one Vault pod per
physical node (which the anti-affinity rule requires) — that would leave only 2
schedulable nodes for 3 Vault pods. This repo is already configured on the
assumption that **the control-plane node also runs Vault** (and similar core
infra): `server.affinity` requires spreading across nodes, and
`server.tolerations` tolerates the control-plane taint so scheduling there is
actually allowed. If your provisioning tool doesn't taint the control-plane at all
(e.g. default k3s server nodes), those tolerations are simply unused — harmless
either way.

If your control-plane taint uses a key other than
`node-role.kubernetes.io/control-plane` or `node-role.kubernetes.io/master`
(both are tolerated already), add it to `server.tolerations` in
`helm/values/vault.yaml` before scaling up — check with:

```
kubectl describe node <control-plane-node-name> | grep Taints
```

## Steps, once the 2 worker nodes have joined the cluster

1. Confirm all 3 nodes are `Ready` and schedulable:
   ```
   kubectl get nodes
   kubectl describe node <control-plane-node-name> | grep Taints   # confirm it matches one of the tolerated keys above
   ```

2. Edit `helm/values/vault.yaml`:
   ```diff
   -    replicas: 1   # bump to 3 once the 2 worker nodes exist — see documentation/scaling-to-ha.md
   +    replicas: 3
   ```
   ```diff
   -    disruptionBudget:
   -      enabled: false
   +    disruptionBudget:
   +      enabled: true
   +      maxUnavailable: 1
   ```
   (`retry_join` and `affinity` need no changes — they were already written for 3
   nodes, see the comments in that file.)

3. Apply:
   ```
   helmfile apply
   kubectl get pods -n vault -o wide -w   # confirm vault-0/1/2 land on 3 different nodes
   ```
   `vault-1` and `vault-2` come up **sealed** — that's expected, every Raft node
   seals independently.

4. Unseal the 2 new pods with 3-of-5 key shares each, same as initial bootstrap
   (see [bootstrap-and-unseal.md](bootstrap-and-unseal.md#4-unseal-all-3-pods)):
   ```
   kubectl exec -n vault -it vault-1 -- vault operator unseal   # x3
   kubectl exec -n vault -it vault-2 -- vault operator unseal   # x3
   ```

5. Confirm all 3 joined as Raft voters:
   ```
   kubectl exec -n vault vault-0 -- vault operator raft list-peers
   ```
   You should see 3 voters. From this point, a single node failure no longer takes
   Vault down — 2-of-3 still forms quorum.

No Terraform changes are needed for this — everything in `terraform/` configures
what's *inside* Vault (policies, auth, secrets engine), which is unaffected by how
many Raft nodes are backing it.

## Don't stop at 2 nodes

If the two new machines don't arrive at the same time, wait for both before
bumping `replicas`. A 2-node Raft cluster needs both nodes up for quorum (2-of-2) —
strictly worse fault tolerance than staying at 1 node, while costing double the
resources. Go straight from 1 to 3.
