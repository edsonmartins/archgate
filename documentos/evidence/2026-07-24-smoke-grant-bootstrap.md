# Evidence — smoke grant + bootstrap (2026-07-24)

## Script

```bash
cd archgate-devops && ./scripts/74-smoke-grant-bootstrap.sh
```

## Result: **PASS**

| Step | Result |
|------|--------|
| Bootstrap unauth | **401** |
| Bootstrap `lab-*` bearer | **200** · 10 connections |
| `test-login?u=testadmin` | session cookie `archguard_session` |
| `POST /api/lab/v1/grant-target` | **200** `ok: true` |
| Grant unauth | **401** |

### Grant detail

```text
Grant rio-aws-api-b → uat-op-a (Warpgate role bound)
- role_resolve ok explicit role tenant-rio-quality
- warpgate ok bound uat-op-a → role tenant-rio-quality
- orchestration ok ok · warpgate:grantAccess · openbao:grantAccess
```

## Stack

- Console image redeployed + `62-wire-console-integrations`
- `ARCHGATE_LAB=1` · `ARCHGUARD_E2E_LOGIN=1` · Warpgate admin wired
- Repos: `archgate-devops` remote `github.com:edsonmartins/archgate-devops` private

## Note

Lab grant API is only for smoke/UAT (`ARCHGATE_LAB` / `E2E_LOGIN`). Production should keep E2E off.
