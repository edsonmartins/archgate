# Plano de código — maturidade do produto (Rio + plataforma)

| Campo | Valor |
|-------|--------|
| Data | 2026-07-17 |
| Escopo | **Somente código** (não onboarding de peer/VPN do cliente) |
| Repos | `archgate`, `archguard` |
| Objetivo | Fechar buracos de produto listados no inventário Rio Quality |

## Critério de pronto

Operador e admin têm **código de produção** para:

1. Multi-connector no inventário (Forti + OpenVPN no mesmo site)
2. Apply de targets com secret via OpenBao (`secret_ref`)
3. Stack Oracle (plugin gRPC + proxy + HCL deploy)
4. Orquestração live (provision/revoke com HTTP real, dry-run opt-in)
5. BFF UnifiedUI (catálogo + callback + sessão)
6. Launch HTTP/observabilidade no operador

Configurar peer Rio no VPS continua **ops**, fora deste plano.

---

## Épico A — Oracle credential path (W3)

| ID | Tarefa | Repo | Done when |
|----|--------|------|-----------|
| A1 | Plugin Go **dbplugin v5** (Initialize/NewUser/UpdateUser/DeleteUser/Type/Close + RotateRoot) | archgate | Binary serve mode + CLI lab |
| A2 | mTLS client obrigatório quando `ORACLE_PROXY_REQUIRE_MTLS=1` | archgate | Client falha sem certs |
| A3 | HCL/catalog/register scripts + stack deploy `replicas` configurável | archgate | Docs + stack.yml |
| A4 | Policy JWT/Kanidm example (amarração identidade) | archgate | HCL de exemplo |
| A5 | Smoke mock E2E plugin→proxy (sem Oracle real) | archgate | Script PASS |

## Épico B — Multi-connector SoT

| ID | Tarefa | Repo | Done when |
|----|--------|------|-----------|
| B1 | Tipo `SiteConnector` + `connectors[]` no modelo | archguard | types + YAML |
| B2 | Persistência `connectors_json` (SQLite + PG) | archguard | migrate + upsert/list |
| B3 | UI form: N connectors (stack, id, subnets, meta) | archguard | form edita array |
| B4 | Checklist por connector_id | archguard | checklist scoped |
| B5 | Compat: site legado 1× stack/connector_id vira array de 1 | archguard | normalize |

## Épico C — Secrets no apply

| ID | Tarefa | Repo | Done when |
|----|--------|------|-----------|
| C1 | `secret_ref` em `SiteTarget` | archguard | type + YAML |
| C2 | `openbaoReadSecret(path)` no proxy | archguard | KV v2 data |
| C3 | `resolveTargetPassword` → request map → OpenBao → env | archguard | apply usa ordem |
| C4 | Test unit resolve chain | archguard | vitest |

## Épico D — Orchestration live

| ID | Tarefa | Repo | Done when |
|----|--------|------|-----------|
| D1 | Warpgate paths alinhados admin API real (users/roles) | archgate | adapter + notes |
| D2 | OpenBao revoke leases por prefixo correto | archgate | API path fix |
| D3 | `ORCH_DRY_RUN=false` executa HTTP (já existia; reforçar logs/errors) | archgate | error surface |
| D4 | Teste unit com MockWebServer ou stub HTTP | archgate | junit |

## Épico E — UnifiedUI BFF

| ID | Tarefa | Repo | Done when |
|----|--------|------|-----------|
| E1 | `GET /api/unified/v1/connections` | archguard | REST JSON RBAC |
| E2 | `POST /api/unified/v1/auth/callback` (session cookie) | archguard | exchange/profile |
| E3 | `POST /api/unified/v1/sessions` (token Guac short-lived / launch meta) | archguard | no admin token no browser |
| E4 | CORS/credentials se SPA em outro host | archguard | env |
| E5 | Frontend: prefer BFF; mock só fallback | archgate | already partial |

## Épico F — HTTP / obs polish

| ID | Tarefa | Repo | Done when |
|----|--------|------|-----------|
| F1 | Snippets HTTP (browser URL Warpgate HTTPS) | archgate unified-ui | launch bundle |
| F2 | Validação apply: kind Http exige host+port | archguard | zod/checks |
| F3 | Doc smoke HTTP target | archgate | runbook snippet |

## Ordem de implementação

```
A (Oracle) ∥ B (multi-conn) ∥ C (secrets)  →  E (BFF)  →  D (orch)  →  F (HTTP)
```

A/B/C são independentes; E depende de sites+targets; D melhora offboarding; F é polish.

## Fora de escopo (explícito)

- Peer Forti/OpenVPN no Hostinger
- Contas VPN institucionais no cliente
- Cluster HA multi-node live
- NetBird
- RDP Windows real
- UnifiedUI E2E Playwright (nice-to-have pós-BFF)

---

## Tracking

| ID | Status | Nota |
|----|--------|------|
| A1 | **done** | `oracle` package + ServeMultiplex; build OK |
| A2 | **done** | `HasMTLSEnv` + require_mtls |
| A3 | **done** | stack.yml replicas, register-plugin.sh, HCL |
| A4 | **done** | JWT policy sketch in HCL |
| A5 | **done** | smoke-plugin-cli.sh |
| B1–B5 | **done** | types, YAML, persist, form, normalize |
| C1–C4 | **done** | secret_ref, readSecretValue, apply chain, unit helpers |
| D1–D4 | **done** | adapters + partial status + junit dry-run |
| E1–E4 | **done** | REST routes under `/api/unified/v1/*` |
| E5 | **done** | SPA already prefers BFF |
| F1–F3 | **done** | HTTP launch snippets + smoke doc |

### Deploy Hostinger (2026-07-18)

**Ops só em `archgate-devops`** (compose + scripts + `config/oracle`).  
Produto (código/Dockerfile) em `archgate/services/*`.

| Serviço | Container | Status |
|---------|-----------|--------|
| oracle-proxy | `archgate-oracle-proxy` | healthy (mock) |
| orchestration | `archgate-orchestration` | healthy (mock) |
| console | `archgate-console` | healthy |
| Script | `archgate-devops/scripts/63-deploy-maturity-services.sh` | PASS |
| Fronteira | `archgate-devops/docs/OPS-BOUNDARY.md` | — |

Atualizar `PLAN-PRODUTO-100.md` na mesma PR de deploy.
