# RustGuac isolated VPS spike — 2026-08-07

## Deployment

- DevOps profile: `session-gateway-spike`;
- image pinned by OCI digest `sha256:1252bd6a138738ce4163a7afacb4b1ae3941c5b71b2c17420e4dc8123c15e2ab`;
- host exposure: `127.0.0.1:18089` only;
- networks: dedicated `archgate_spike-loopback` plus `linktor-internal`;
- no `linktor-edge`, Traefik route, Docker socket or control-plane token;
- resource limits: 1.5 GiB RAM, 1.5 CPU and 512 PIDs;
- `cap_drop=ALL`, `no-new-privileges=true`, non-root runtime.

## Smoke evidence

```text
HTTPS root: 200
container restarts: 0
idle memory: 16.57 MiB
idle CPU: 0.00%
processes: 3
target banner: SSH-2.0-OpenSSH_10.3 (archgate-lab-ssh:2222)
```

The first-run `docker-admin` API key was treated as compromised because the
upstream entrypoint writes it to container logs. It was deleted. A replacement
`archgate-spike` key was generated without terminal output, restricted to the
internal bridge CIDR, expires on 2026-08-14 and is stored only in a root-owned
mode-0600 file on the VPS. Transient GHCR credentials were removed after pull.

## Remaining executable gates

This proves build, process startup, isolation and target reachability. It does
not approve the upstream process for production. Tasks 2.3–2.6 still require an
ArchGate-owned session ticket path, replay test, browser/log secret inspection
and recording correlation with a synthetic `pcid`.
