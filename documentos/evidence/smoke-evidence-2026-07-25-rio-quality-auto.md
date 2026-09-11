# Rio Quality — relatório automático de validação

| Campo | Valor |
|-------|--------|
| Início (UTC) | 2026-07-25T22:50:18.336266+00:00 |
| Fim (UTC) | 2026-07-25T22:50:22.203189+00:00 |
| PASS | 11 |
| FAIL | 0 |
| WARN | 0 |
| SKIP | 10 |
| Decisão automática | **PASS** (FAIL se qualquer check FAIL) |

## Ambiente

| Key | Value |
|-----|--------|
| `console_url` | `https://console.archgate.com.br` |
| `bastion_host` | `217.196.60.108` |
| `bastion_ssh_port` | `2222` |
| `bastion_pg_port` | `55432` |
| `wg_user` | `uat-op-a` |
| `deep` | `False` |
| `has_password` | `***` |
| `remote_peer` | `False` |
| `vps_host` | `` |
| `devops_scripts` | `False` |
| `archgate_cli` | `/Users/edsonmartins/.local/bin/archgate` |

## Checks

| ID | Categoria | Status | Título | Detalhe | ms |
|----|-----------|--------|--------|---------|----|
| P1 | platform | **PASS** | Console HTTPS | HTTP 307 → /dashboard | 205 |
| P2 | platform | **PASS** | archguard id HTTPS | HTTP 303 → /ui | 196 |
| P3 | platform | **PASS** | Warpgate UI HTTPS | HTTP 307 → /@warpgate#/login?next=%2F | 145 |
| P4 | platform | **PASS** | Guacamole HTTPS | HTTP 200 | 147 |
| P5 | platform | **PASS** | Bastion SSH TCP | 217.196.60.108:2222 OPEN (18ms) | 18 |
| P6 | platform | **PASS** | Bastion Postgres TCP | 217.196.60.108:55432 OPEN (18ms) | 18 |
| B1 | bootstrap | **PASS** | Bootstrap unauth → 401 | 401 Unauthorized (expected) | 192 |
| B2 | bootstrap | **PASS** | Bootstrap lab bearer → catalog | 10 connections · rio=10 · ssh=217.196.60.108:2222 | 2304 |
| B3 | bootstrap | **PASS** | Sessions API (lab bearer) | HTTP 200: {'tunnel_url': '', 'connect_data': '', 'expires_in': 120, 'launch': {'engine': 'warpgate', 'target': 'rio-l… | 119 |
| I1 | connect | **PASS** | archgate CLI version | archgate 0.2.0-dev (darwin/arm64) | 295 |
| I2 | connect | **PASS** | archgate doctor --json | 6 checks OK | 220 |
| S0 | ssh | **SKIP** | SSH deep checks | Set RIO_WG_PASSWORD or UAT_PASS_uat_op_a (and RIO_DEEP=1) for live SSH | 0 |
| C0 | postgres | **SKIP** | Postgres deep checks | Set RIO_WG_PASSWORD for live psql | 0 |
| A0 | peer | **SKIP** | Remote peer probes | Set ARCHGATE_HOST (+ key) and RIO_REMOTE_PEER=1 | 0 |
| D0 | devops | **SKIP** | Devops smoke scripts | Set RIO_DEVOPS_SCRIPTS=1 to run 67/74 | 0 |
| H1 | admin | **SKIP** | Manager /sites/rio_quality visual | MANUAL: Browser: dual connectors + targets | 0 |
| H2 | admin | **SKIP** | Viewer deny UI | MANUAL: Login uat-viewer — sem mutações | 0 |
| F1 | guac | **SKIP** | Guacamole SSO visual | MANUAL: Browser guac.archgate.com.br | 0 |
| D3 | oracle | **SKIP** | Oracle lease E2E real | MANUAL: Manager /oracle + JDBC mock=false | 0 |
| I5 | connect | **SKIP** | Connect preferências terminal | MANUAL: UI Preferências global/por target | 0 |
| U1 | uat | **SKIP** | Assinatura §6.2 | MANUAL: PLAN-HOMOLOGACAO-MVP.md | 0 |

## Manual (humano / browser)

- [ ] **H1** Manager /sites/rio_quality visual — MANUAL: Browser: dual connectors + targets
- [ ] **H2** Viewer deny UI — MANUAL: Login uat-viewer — sem mutações
- [ ] **F1** Guacamole SSO visual — MANUAL: Browser guac.archgate.com.br
- [ ] **D3** Oracle lease E2E real — MANUAL: Manager /oracle + JDBC mock=false
- [ ] **I5** Connect preferências terminal — MANUAL: UI Preferências global/por target
- [ ] **U1** Assinatura §6.2 — MANUAL: PLAN-HOMOLOGACAO-MVP.md

## Próximos passos

- Preencher residual em [`VALIDACAO-RIO-QUALITY.md`](../../runbooks/sites/VALIDACAO-RIO-QUALITY.md)
- SSH/PG deep: `export UAT_PASS_uat_op_a='…' RIO_DEEP=1`
- Peers no VPS: `export ARCHGATE_HOST=… ARCHGATE_SSH_KEY=… RIO_REMOTE_PEER=1`
- Scripts devops: `RIO_DEVOPS_SCRIPTS=1`

