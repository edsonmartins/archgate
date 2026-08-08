# Evidence — ArchGate Connect SSO E2E (template)

| Campo | Valor |
|-------|--------|
| **Data** | YYYY-MM-DD |
| **Operador** | |
| **Host** | macOS / Linux / Windows |
| **CLI** | `archgate x.y.z` |
| **Resultado** | PASS / FAIL / BLOCKED |

## How to run

```bash
cd clients/archgate-connect
# 1) non-interactive
./scripts/smoke-sso-e2e.sh --preflight

# 2) interactive (opens browser — complete archguard login)
./scripts/smoke-sso-e2e.sh --interactive
# writes documentos/evidence/YYYY-MM-DD-archgate-connect-sso-e2e.md
```

## Checklist

- [ ] Discovery OIDC `archgate-connect` HTTP 200  
- [ ] `oidc.env` secret present (not committed)  
- [ ] Browser opened to archguard authorize URL  
- [ ] Callback `127.0.0.1:8765` completed  
- [ ] `archgate status --json` → `auth=oidc`, `session=true`, `token_ok=true`  
- [ ] `connections` ≥ 1 (or expected empty catalog)  
- [ ] Refresh: wait near expiry or force `expires_at` past → `status` still works  
- [ ] `archgate logout` clears session / keychain  

## Result notes

_Preflight automated PASS is tracked in H4 evidence. Interactive PASS requires a human operator on this template or the generated file from `smoke-sso-e2e.sh --interactive`._

## Blockers (if any)

| Blocker | Owner |
|---------|--------|
| | |
