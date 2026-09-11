# Runbook — Rotação de segredos (W1-SEC04)

**Nunca** commitar valores. Bootstrap: `/root/archgate/bootstrap.env` (mode 600).

| Segredo | Onde vive | Rotação (resumo) | Impacto |
|---------|-----------|------------------|---------|
| `SESSION_SECRET` | bootstrap + env console | Gerar 32+ bytes hex; update bootstrap; `deploy-console.sh` ou `service update --env-add` | Sessões console invalidadas |
| `ARCHGUARD_SA_TOKEN` | bootstrap + console | `archguard` service account API token novo; atualizar bootstrap + console | Provision/admin API console |
| `WARPGATE_ADMIN_PASSWORD` | bootstrap + console + ops | Admin API Warpgate + env console | Apply gateways / admin WG |
| `OPENBAO_APP_TOKEN` | bootstrap + console + broker | Policy token OpenBao; revogar antigo | Secrets UI, broker DB, smokes |
| `OPENBAO_ROOT_TOKEN` | bootstrap **só ops** (não no console W1) | Re-init só em disaster — evitar | Full OpenBao |
| `OPENBAO_UNSEAL_KEY` | bootstrap + **systemd unseal** (não app) | Shamir rekey (ops) | Unseal |
| `POSTGRES_*_PASSWORD` | bootstrap + PG | `ALTER ROLE` + update bootstrap + services | Warpgate/Guac/console DBs |
| OIDC client secrets | bootstrap + archguard OAuth2 | `archguard system oauth2` reset secret | SSO clients |
| `TARGET_SECRET_*` | env console ou OpenBao | Por alvo; sem senha no inventário sites | Apply targets |
| UAT passwords | `/root/archgate/uat-credentials.env` | `provision-uat-users.sh` | Lab UAT only |

## Procedimento genérico

1. Gerar novo valor (`openssl rand -hex 32` ou ferramenta do produto).  
2. Aplicar no **sistema de origem** (archguard / OpenBao / PG / WG).  
3. Atualizar `bootstrap.env` no host.  
4. Redeploy / `docker service update --env-add` dos consumidores.  
5. Smoke mínimo: `health-monitor.sh` + login ou smoke-operator.  
6. Revogar valor antigo quando houver dual-run.

## Política W1 (console)

| Permitido no console | Proibido no console (W1) |
|----------------------|---------------------------|
| `OPENBAO_APP_TOKEN` | `OPENBAO_ROOT_TOKEN` |
| `WARPGATE_ADMIN_*` (control plane) | `OPENBAO_UNSEAL_KEY` |
| `TARGET_SECRET_*` por alvo | `LAB_SSH_PASSWORD` global |
| | `ARCHGUARD_E2E_LOGIN` (exceto janela UAT lab) |

```bash
# aplicar harden no runtime
ARCHGATE_LAB=0 bash deploy/archguard/harden-console-env.sh
```
