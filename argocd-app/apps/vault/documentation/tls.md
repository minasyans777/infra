# TLS

Vault's listener, Raft peer traffic, and API are all TLS-only
(`global.tlsDisable: false` in `helm/values/vault.yaml`) — nothing in this cluster
talks to Vault over plaintext.

## Why a private CA, not the existing `letsencrypt-prod` ClusterIssuer

`gitops`/`registration` already have a working `letsencrypt-prod` ClusterIssuer
(public ACME, HTTP-01 via Traefik) for tenant-facing hostnames. Vault doesn't use it,
because:

- The certificate needs SANs for internal cluster DNS
  (`vault-0.vault-internal`, `vault-active`, ...) that a public CA has no reason to
  issue for and Let's Encrypt would refuse.
- Vault's API is never exposed publicly (see the main [README](../README.md)), so
  there's no browser-trust requirement a private CA can't satisfy.

`tls/10-bootstrap-issuer.yaml` mints a long-lived (10y) private CA once, then
`tls/20-server-certificate.yaml` issues one certificate off that CA, shared by all 3
pods via `server.extraVolumes` in the Helm values.

## Rotation

cert-manager renews `vault-server-tls` automatically 15 days before expiry (90-day
cert, see `renewBefore` in `tls/20-server-certificate.yaml`), but **Vault does not
hot-reload a changed TLS secret** — each pod needs a rolling restart
(`kubectl rollout restart statefulset/vault -n vault`) after cert-manager rewrites
the secret for the new cert to actually take effect. Not currently automated (e.g.
via Reloader, which `gitops` already uses for application secrets) — add
`reloader.stakater.com/auto: "true"` to the StatefulSet's pod template if that's
wanted, but a raft node restart is more disruptive than a normal app pod restart, so
this was left manual deliberately for now.

The CA certificate itself is 10-year duration — rotating it means re-issuing every
pod's certificate and updating trust, which is a bigger, rarer operation not
automated here.

## "Not secure" in the browser when opening the UI

Expected, not a bug — confirm with `kubectl get certificate -n vault vault-server-tls`
that it's actually `Ready`/up to date before assuming otherwise. The warning just
means your browser doesn't recognize the private `vault-ca` issuer (see above for
why it's private rather than `letsencrypt-prod`); the connection itself is still
correctly encrypted and the chain is valid. Two options:

- Click through it (Chrome: Advanced → Proceed; Firefox: Advanced → Accept the
  Risk and Continue) — fine to do every time, this is an internal admin-only UI
  reached via `kubectl port-forward`, not a publicly trusted endpoint.
- Or trust `vault-ca` locally so the warning stops appearing:
  ```
  kubectl get secret -n vault vault-ca-key-pair -o jsonpath='{.data.ca\.crt}' | base64 -d > vault-ca.crt
  ```
  then import `vault-ca.crt` as a trusted root — `sudo cp vault-ca.crt
  /usr/local/share/ca-certificates/ && sudo update-ca-certificates` on
  Debian/Ubuntu (covers Chrome), `sudo security add-trusted-cert -d -r trustRoot -k
  /Library/Keychains/System.keychain vault-ca.crt` on macOS, or Firefox's own
  Settings → Privacy & Security → Certificates → View Certificates → Authorities →
  Import (Firefox uses its own store on every OS, not the system one).
