# Evidence — push + smoke first-use (2026-07-24)

## Git push

| Repo | Result | Tip |
|------|--------|-----|
| `archgate` | **pushed** `13458a0` → `origin/main` | connect + plan |
| `_archguard` / archguard | **pushed** `47adf58` → `origin/main` | RBAC, grant, vite stubs |
| `archgate-devops` | **no remote** | commit local `c7597ed` only |

## Deploy

- `61-deploy-console.sh` PASS · `archgate-console` healthy
- Image contains `bindWarpgateUserRole` (`lifecycle-fn-*.js`, `warpgate-proxy-*.js`)
- `ARCHGATE_CONNECT_LAB=1` on container

## Smoke results

| Check | Result |
|-------|--------|
| `GET …/operator/bootstrap` no auth | **401** `{"error":"Unauthorized"}` |
| `GET …/bootstrap` `Bearer lab-smoke.operator` | **200** bastion + catalog |
| Connect mock `68-smoke-archgate-connect.sh` | **PASS** |
| Connect live lab `ARCHGATE_MOCK=0` + `login --lab` | **PASS** · 10 connections · doctor catalog OK |
| Bastion TCP 2222 / 55432 | **OPEN** |
| `print-ssh rio-aws-api-b` | `uat-op-a:rio-aws-api-b@217.196.60.108` |
| SSH BatchMode (no password) | `Permission denied (password)` — expected; WG reached |
| Grant server fn interactive | **not** exercised (needs admin session cookie); code present in image |

## Residual next (F1)

1. SSH interativo com senha UAT `uat-op-a` até shell no host real  
2. Grant via UI Manager (pessoa → Grant target) com sessão admin  
3. Assinar §6.2  
4. Configurar remote git para `archgate-devops` se quiser push do residual  
