# vault-backup

Daily Vault raft snapshot, written to a node-local PVC in the `vault` namespace.

Managed by the Argo CD Application in `../vault-backup.yaml`, using this chart's
`values.yaml`. Like the Vault Application, it is synced manually.

## One-time setup

1. Create a Vault token scoped to snapshot-only access (see the comment in
   `values.yaml` for the exact `vault policy write` / `vault token create`
   commands), then:

   ```
   kubectl create secret generic vault-backup-token -n vault \
     --from-literal=token=<the token>
   ```

2. Ensure the `vault` namespace and `vault-server-tls` Secret exist, then register
   the Application (from this directory):

   ```
   kubectl apply -f ../vault-backup.yaml
   ```

3. Sync the `vault-backup` Application in Argo CD. Push chart or values changes
   to Git and sync again to deploy updates.
