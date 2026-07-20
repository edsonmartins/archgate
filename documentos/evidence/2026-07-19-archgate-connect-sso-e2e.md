# Evidence — ArchGate Connect SSO E2E

| Campo | Valor |
|-------|--------|
| **Data** | 2026-07-20T01:23Z |
| **Host** | Darwin/arm64 |
| **CLI** | `archgate 0.2.0-dev (darwin/arm64)` |
| **Result** | **PASS** interactive PKCE |
| **Artifacts** | `/var/folders/jg/vtx6sxh95r5dm1lsl3nbljww0000gn/T/tmp.HfHSLlQm8j` (local tmp; not committed secrets) |

## Checks

- [x] Browser PKCE login completed
- [x] `status --json` auth=oidc session=true
- [x] Token usable for catalog/bootstrap (see connections count in status)

```
auth=oidc
user=testadmin@id.archgate.com.br
connections=11
```

Tokens are **not** copied into this file.
