# Plano de implementação — o que falta (pós 2026-07-18)

| Campo | Valor |
|-------|--------|
| Status | **Ativo** |
| Objetivo | Checklist **executável** do residual vs specs (`PLAN-PRODUTO-100`, homologação MVP, console AWS) |
| Baseline | Hostinger staging H1 **done**; console W-C1–W-C4 (parcial Oracle) **done**; peer Rio **blocked** |
| Data | 2026-07-18 |
| Dono | Edson Martins |
| Specs de referência | [`PLAN-PRODUTO-100.md`](./PLAN-PRODUTO-100.md) · [`PLAN-HOMOLOGACAO-MVP.md`](./PLAN-HOMOLOGACAO-MVP.md) · [`../archgate-devops/docs/CONSOLE-NORTH-STAR.md`](../../archgate-devops/docs/CONSOLE-NORTH-STAR.md) |

### Repos

| Repo | Escopo |
|------|--------|
| `archgate-devops` | Compose, scripts, inventário, agent, deploy VPS |
| `archguard` | Console admin (control plane) |
| `archgate` | Serviços (oracle-proxy, orchestration, plugin, UnifiedUI SPA) |

### Tipos de tarefa

| Tipo | Significado |
|------|-------------|
| `code` | Implementação de software |
| `ops` | Deploy/config na VPS (via devops) |
| `data` | Dado/conta do cliente (calendário) |
| `uat` | Validação humana / assinatura |

---

## 0. Princípios (não negociar)

1. **Console tipo AWS** — happy path sem SSH; scripts = bootstrap/break-glass.  
2. **Ops no devops** — não deixar procedimento só em chat ou monorepo.  
3. **Marcar `[x]` só com evidência** (smoke, print, path em `/root/archgate` ou PR).

---

## Fase A — Fechar homologação MVP (M1) · **P0**

**Critério de saída:** §6.2 assinado (APTO ou APTO c/ waiver peer) + UAT revisor ≤ 30 min.

### A1 — Peer Rio Quality (H2 / W0-B)

| ID | Tarefa | Tipo | Repo | Depende | Aceite |
|----|--------|------|------|---------|--------|
| **A1.1** | Contato Rio: contas Forti + OpenVPN **institucionais**, subnets, janela | `data` | — | — | Contas + CIDRs documentados em `archgate-devops/inventory/clients/rio-quality.md` |
| **A1.2** | Preencher ficha real SoT (console wizard ou import YAML) com hosts SSH/PG/Oracle | `ops`+`data` | archguard / devops inventory | A1.1 | Site `rio_quality` inventariado ≠ só lab |
| **A1.3** | Materializar dual connector no console (Forti + OpenVPN) via agent | `ops` | archguard + agent | A1.1 | Units active; probe TCP PASS |
| **A1.4** | Apply targets reais Warpgate (secret_ref OpenBao) | `ops` | archguard | A1.2–A1.3 | `uat-op-a` SSH e/ou PG no host real |
| **A1.5** | Isolamento: operador Marra **não** alcança Rio real | `uat` | — | A1.4 | Matriz deny documentada |
| **A1.6** | Evidência `smoke-evidence-YYYY-MM-DD-rio-quality.md` | `uat` | documentos | A1.4–A1.5 | Arquivo no repo + path VPS |

**Scripts break-glass (só se agent falhar):** `64` / `65` no devops.

### A2 — UAT formal revisor

| ID | Tarefa | Tipo | Repo | Depende | Aceite |
|----|--------|------|------|---------|--------|
| **A2.1** | OIDC browser real (não só test-login) console + WG | `uat` | — | H1 | Print/cadeado + cookie Secure |
| **A2.2** | Viewer deny UI (persona viewer) | `uat` | archguard se bug | A2.1 | 403/empty documentado |
| **A2.3** | Seguir [`HOMOLOGACAO-UAT.md`](./runbooks/HOMOLOGACAO-UAT.md) ponta a ponta | `uat` | — | A1.4 ou waiver lab | Checklist assinado |
| **A2.4** | Assinar §6.2 (APTO / ressalvas / waiver peer) | `uat` | PLAN-HOMOLOG | A2.3 | Assinatura + data |

### A3 — Higiene pós-UAT (entrada M2)

| ID | Tarefa | Tipo | Repo | Aceite |
|----|--------|------|------|--------|
| **A3.1** | Plano `ARCHGATE_LAB=0` + desligar E2E login se desejado | `ops` | devops | Env documentado |
| **A3.2** | OPENBAO_APP_TOKEN only (sem root no console diário) | `ops` | devops | Console usa app token |
| **A3.3** | MFA enforcement operadores (Kanidm policy) | `ops`+`code` | archguard / kanidm | Policy aplicada; doc `mfa-operadores.md` |

**Gate A:** M1 fechado → pode chamar “homologado (com ressalvas se waiver)”.

---

## Fase B — 1º cliente operacional (M2) · **P0/P1**

**Critério de saída:** time Rio opera sem VPN no notebook; offboarding 1 clique; backups ok.

| ID | Tarefa | Tipo | Repo | Aceite |
|----|--------|------|------|--------|
| **B1** | 4 operadores no tenant + provision/grant na UI | `ops` | archguard | Logins SSO; targets corretos |
| **B2** | Offboarding E2E real (sair 1 dev) | `uat` | archguard | Kanidm expire + sem SSH |
| **B3** | Runbook incidente 1 página (só console + break-glass) | `ops` | devops docs | Link no README devops |
| **B4** | Secrets só OpenBao (zero senha em inventário/git) | `ops` | archguard | Audit: secret_ref em todos targets sensíveis |
| **B5** | Orch **live** calibrado (não mock) para revoke/grant | `ops`+`code` | archgate orch + devops | `ORCH_MODE=live`, dry-run false em janela controlada; smoke PASS |

---

## Fase C — Oracle produção Consinco (W3) · **P1** (Rio)

**Critério de saída:** lease dinâmico E2E ou N/A formal assinado.

| ID | Tarefa | Tipo | Repo | Aceite |
|----|--------|------|------|--------|
| **C1** | JDBC real no oracle-proxy (`ORACLE_PROXY_MOCK=false`) + secret admin | `ops`+`data` | devops + oracle-proxy | Health + create user no PDB/serviço real |
| **C2** | Build + register plugin OpenBao no VPS | `ops` | devops `config/oracle` + monorepo plugin | `database/creds/oracle-readonly` 200 |
| **C3** | mTLS proxy↔plugin (ou rede só internal + doc risco) | `code`+`ops` | archgate + devops | Enforce documentado |
| **C4** | Policy JWT/Kanidm → quem pode emitir lease | `ops` | openbao | Policy bound a grupo tenant |
| **C5** | E2E: UI Oracle → emitir → SQL\*Plus/DBeaver → revogar | `uat` | archguard `/oracle` | Smoke-evidence |
| **C6** | Amarração site Rio: target meta + secret_ref opcional | `ops` | archguard | Ficha site com nota Oracle |

---

## Fase D — Rede multi-site + protocolos (W2 residual) · **P1/P2**

| ID | Tarefa | Tipo | Repo | Aceite |
|----|--------|------|------|--------|
| **D1** | openfortivpn E2E documentado (1º Forti real) = A1.3 evidência | `uat` | devops | Checklist W2-SITE04 |
| **D2** | 2º site Grupo Marra peer real | `data`+`ops` | archguard + devops | Isolamento A/B |
| **D3** | HTTP target UX operador (snippet + open browser) | `code` | archguard + unified-ui | Smoke http-target |
| **D4** | MySQL Warpgate se inventário tiver MySQL | `code`+`ops` | archguard | Apply + cliente local |
| **D5** | RDP Windows real (só se host existir) | `data`+`ops` | guac | Guac RDP PASS ou waiver |
| **D6** | K8s Warpgate (se demanda) | `code` | archguard | Target kind K8s |
| **D7** | WireGuard peer na UI agent (além Forti/OVPN) | `code` | agent + archguard | Materializar WG pela UI |
| **D8** | NetBird | — | — | **Só se** multi-site exigir (ADR-010 defer) |

---

## Fase E — UnifiedUI operador + orquestração (M4) · **P1/P2**

| ID | Tarefa | Tipo | Repo | Aceite |
|----|--------|------|------|--------|
| **E1** | Deploy SPA UnifiedUI em `app.archgate.com.br` | `ops` | devops + archgate frontend | HTTPS 200 |
| **E2** | Client OIDC `archgate-unified-ui` no Kanidm | `ops` | devops script 60 | Login real |
| **E3** | BFF cookie session (já em archguard) + CORS | `ops` | archguard | Catálogo sem mock |
| **E4** | E2E browser smoke UnifiedUI (Playwright) | `code` | archgate/archguard | CI ou script PASS |
| **E5** | Orch live paths WG/Kanidm calibrados (ver B5) | `ops` | archgate | Grant/revoke live |
| **E6** | Terraform provider WG | `code` | — | Opcional / N/A |

**Critério M4:** operador não precisa de 3 UIs no happy path; offboarding 1 ação (já no admin).

---

## Fase F — Console polish residual (north-star) · **P2**

| ID | Tarefa | Tipo | Repo | Aceite |
|----|--------|------|------|--------|
| **F1** | Painel ops: last backup / health timers (read-only) | `code`+`ops` | archguard + devops | Dashboard mostra last success |
| **F2** | DNS/cert checklist read-only (Cloudflare status) | `code` | archguard | Página ou card platform |
| **F3** | MFA status na ficha pessoa (enforcement UI) | `code` | archguard | Badge MFA |
| **F4** | Gravações WG/Guac na timeline auditoria | `code` | archguard | Links path gravação |
| **F5** | Multi-connector status green/red por id na UI | `code` | archguard + agent | Runtime por connector |

---

## Fase G — HA + agêntico (M5 / 100%) · **P3**

| ID | Tarefa | Tipo | Repo | Aceite |
|----|--------|------|------|--------|
| **G1** | OpenBao Raft multi-node + auto-unseal | `ops` | devops | Failover checklist PASS |
| **G2** | Kanidm topologia HA (se SLA exigir) | `ops` | devops | Doc + smoke |
| **G3** | Traefik multi-node pattern | `ops` | linktor/devops | Doc |
| **G4** | Agent-control E2E live (HITL + kill-switch) | `code`+`uat` | archgate | Smoke live |
| **G5** | Bootstrap OpenSRE SA live Kanidm | `ops` | devops | SA + policy |
| **G6** | Atualizar `MATRIZ_FUNCIONALIDADES.md` zero Pendente crítico | `ops` | documentos | PR |
| **G7** | Aceite 100% assinatura arquiteto | `uat` | — | Assinatura |

---

## Ordem de execução sugerida (sprints)

```text
Sprint 1 (agora)     A1 peer Rio + A2 UAT + A3 higiene     → M1
Sprint 2             B1–B5 1º cliente operacional          → M2
Sprint 3             C1–C5 Oracle E2E Consinco             → W3
Sprint 4             D2 Marra + D3–D4 protocolos           → W2
Sprint 5             E1–E5 UnifiedUI + orch live           → M4
Sprint 6+            F* polish · G* HA/agêntico            → M5
```

### Paralelo possível

- **C*** (Oracle) // com **B*** se peer Forti já entrega rede ao Oracle.  
- **E*** (UnifiedUI) // com **B*** (admin já tem lifecycle).  
- **G*** só após M2 estável.

---

## Backlog de implementação por repo (checklist rápido)

### `archgate-devops`

- [ ] **A1.*** inventário Rio preenchido + evidência peer  
- [ ] **A3.*** bootstrap.env prod flags  
- [ ] **B5 / E5** orch live env documentado  
- [ ] **C2** register-plugin OpenBao  
- [ ] **E1** compose/Traefik `app.` UnifiedUI  
- [ ] **F1** expor métricas backup para console (opcional API/file)  
- [ ] **G1–G3** HA  

### `archguard` (console)

- [ ] Bugs UAT A2.* se aparecerem  
- [ ] **D3** HTTP target UX  
- [ ] **D7** WG peer no agent UI  
- [ ] **F1–F5** polish  
- [ ] **C5** polimento Oracle UI pós-JDBC  

### `archgate` (serviços)

- [ ] **C1/C3** oracle-proxy JDBC + mTLS  
- [ ] **C2** plugin binário/registro  
- [ ] **B5** adapters orch live paths reais  
- [ ] **E*** UnifiedUI SPA deployable  
- [ ] **G4–G5** agentic live  

---

## Explicitamente **fora** deste plano (estacionamento)

| Item | Motivo |
|------|--------|
| NetBird como default | ADR-010: connectors first |
| SIEM enterprise | Fora visão 100% atual |
| Multi-região global | Não no M5 atual |
| Reescrever Warpgate/Kanidm | Integração, não fork |

---

## Como marcar progresso

1. Ao fechar um ID: `[x]` + data + link evidência neste arquivo ou smoke-evidence.  
2. Atualizar `PLAN-PRODUTO-100.md` §3 radar e §15 changelog.  
3. Atualizar `PLAN-HOMOLOGACAO-MVP.md` sprints H2/H3.  
4. Atualizar `CONSOLE-NORTH-STAR.md` se for gap de UI.

---

## Próxima ação imediata (começar por aqui)

| # | ID | Ação concreta | Status 2026-07-18 |
|---|-----|----------------|-------------------|
| 0 | **A0** | `./scripts/67-sprint1-readiness.sh` (plataforma) | **Sprint 1 started** |
| 1 | **A1.1** | Form + e-mail: `archgate-devops/inventory/clients/rio-quality-coleta-A1.1.md` | **in_progress** — aguarda Rio |
| 2 | **A1.2** | Wizard console / ficha `reais/rio-quality.yaml` | pending dados |
| 3 | **A1.3–A1.4** | Materializar connectors + targets no console | pending A1.1 |
| 4 | **A2.*** | UAT browser + §6.2 | pending |

Sprint tracking: `archgate-devops/docs/SPRINT-1-HOMOLOG.md`.

Sem **A1.1** (dados do cliente), o restante de homologação fica artificial (só lab).

---

## Changelog

| Data | Mudança |
|------|---------|
| 2026-07-18 | Criação: fases A–G do residual pós-console maturity / Hostinger H1 |
| 2026-07-18 | Sprint 1 iniciado: coleta A1.1 + readiness 67 + ficha dual connector |
