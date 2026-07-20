# Closeout — residual Connect (2026-07-20)

## Product scope: **CLOSED for lab/homolog**

| Área | Status |
|------|--------|
| CLI + desktop + tray | done |
| SSO OIDC E2E | **PASS** (`2026-07-19-archgate-connect-sso-e2e.md`) |
| H6 bastion path smoke | **PASS** (lab + expanded) |
| Keychain / multi-OS docs | done |
| Codesign ad-hoc / package script | done |
| Forti XOR policy | documented + VPS Forti off while Mac uses Forti |

## Ops closed this session

| Item | Result |
|------|--------|
| AWS Warpgate client keys (`72` + PEM) | **OK** 10.0.25.18, 10.0.25.62, 10.0.31.102 |
| Postgres targets `rio-aws-pg-a/b` (`73`) | **created** in Warpgate DB |
| WG user `testadmin` + roles | **created** (SSO parity with tenants) |
| `uat-op-a` + `archgate-operators` | ensured |

## Explicitly **not** closed (org / Apple / process)

| Item | Why |
|------|-----|
| **Notarize + Developer ID** | Machine has only *Apple Development* identity — cannot notarize for third-party Gatekeeper without Developer ID Application + notary credentials |
| **H6 “one full day without client VPN”** | Human process; product path is proven |
| **Forti service account** | Requires Rio IT / Forti admin (not `suporte.mentors*`) |
| **DB password secrets on PG targets** | Targets exist; Warpgate still needs real DB credentials for proxy auth if password-kind |

## Operator playbook (done)

```bash
# SSO
archgate login

# Lab
archgate login --lab --user YOU

archgate doctor
archgate ls
archgate go <target> --terminal
archgate config apply

# Package local
./clients/archgate-connect/scripts/package-macos.sh
```

## When Apple cert arrives

See `documentos/runbooks/archgate-connect-macos-notarize.md`.
