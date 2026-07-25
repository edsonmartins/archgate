# Rio Quality — validador automático

Aplicação **Python 3 stdlib** (sem pip) que executa o que for automatizável do runbook  
[`VALIDACAO-RIO-QUALITY.md`](../../../documentos/runbooks/sites/VALIDACAO-RIO-QUALITY.md)  
e gera relatório **Markdown + JSON**.

## Uso rápido

Na raiz do monorepo `archgate`:

```bash
# Só edge + bootstrap + TCP bastion + CLI (se existir)
python3 -m deploy.validation.rio_quality_report

# Com SSH/psql reais (precisa senha Warpgate do operador)
export UAT_PASS_uat_op_a='…'   # ou RIO_WG_PASSWORD
python3 -m deploy.validation.rio_quality_report --deep

# Peers na VPS via SSH
export ARCHGATE_HOST=217.196.60.108
export ARCHGATE_SSH_KEY=~/.ssh/linktor_vps_key
python3 -m deploy.validation.rio_quality_report --remote-peer

# Tudo o que dá (mais lento)
python3 -m deploy.validation.rio_quality_report \
  --deep --remote-peer --devops-scripts
```

Ou:

```bash
./deploy/validation/rio_quality_report/run.sh
```

## Saída

Por padrão em `documentos/evidence/`:

- `smoke-evidence-YYYY-MM-DD-rio-quality-auto.md`
- `smoke-evidence-YYYY-MM-DD-rio-quality-auto.json`

Decisão automática: **FAIL** se qualquer check `FAIL`; `WARN`/`SKIP` não derrubam o exit code 0…  
(exit code **1** se houver FAIL).

## O que é automático vs manual

| Automático | Manual (SKIP no relatório) |
|------------|----------------------------|
| HTTPS console/id/wg/guac | Manager UI visual |
| Bootstrap 401 + lab catalog | Viewer deny browser |
| TCP bastion 2222/55432 | Guac SSO visual |
| Sessions API Bearer | Oracle lease E2E real |
| `archgate doctor` (se CLI) | Preferências Connect UI |
| SSH lab/AWS + deny Marra (`--deep` + senha) | Assinatura §6.2 |
| psql lab/AWS (`--deep`) | |
| Peer probes no VPS (`--remote-peer`) | |
| Scripts 67/74 (`--devops-scripts`) | |

## Variáveis de ambiente

| Var | Default | Uso |
|-----|---------|-----|
| `CONSOLE_URL` | `https://console.archgate.com.br` | BFF |
| `BASTION_HOST` | `217.196.60.108` | SSH/PG |
| `RIO_WG_USER` | `uat-op-a` | deep SSH/PG |
| `UAT_PASS_uat_op_a` / `RIO_WG_PASSWORD` | — | deep |
| `RIO_TARGET_SSH_AWS` | `rio-aws-api-b` | deep SSH |
| `RIO_LAB_TOKEN` | `lab-rio-report` | bootstrap Bearer |
| `ARCHGATE_HOST` | — | SSH VPS peer |
| `ARCHGATE_SSH_KEY` | `~/.ssh/linktor_vps_key` | peer |
| `RIO_REPORT_DIR` | `documentos/evidence` | output |
| `ARCHGATE_CLI` | `~/.local/bin/archgate` | doctor |

## Dependências opcionais (deep)

- `sshpass` — SSH com senha Warpgate  
- `psql` — Postgres via bastion  
- `ssh` + chave — probes remotos no VPS  

## Limitações

- Não substitui UAT humano (§6.2, browser SSO visual).  
- SSH deep usa password auth; agent/pubkey não testados aqui.  
- Oracle JDBC real e RDP Windows ficam manuais / N/A.  
