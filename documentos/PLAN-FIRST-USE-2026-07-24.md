# Plano — 1ª versão de uso (auditoria + execução)

| Campo | Valor |
|-------|--------|
| Data | 2026-07-24 |
| Origem | Auditoria core + admin (Manager) + Connect |
| Critério “1ª versão” | Operador SSO → catálogo → SSH/PG bastion **sem VPN no notebook**; admin inventaria site e lifecycle no Manager |
| Fora de escopo v1 | UnifiedUI, Oracle real, HA, NetBird, agentic/OpenSRE |
| Dono | Edson Martins |

---

## 1. Achados registrados (auditoria)

### 1.1 Core (archgate + devops + runtime)

| ID | Achado | Severidade | Tipo |
|----|--------|------------|------|
| C-OK | Staging Hostinger ensaiável; Kanidm/WG/Guac/OpenBao/console healthy | — | ok |
| C-OK | Dual peer Rio (Forti+OpenVPN) materializado; targets AWS SSH no WG | — | ok |
| C1 | UAT formal + assinatura §6.2 pendente | P0 | processo |
| C2 | Gestor LAN `rio-gestor-linux`: authorized_keys Warpgate pendente | P0 ops | ops |
| C3 | PG `rio-aws-pg-*` sem secret real no WG | P0 ops (se DB day-1) | ops |
| C4 | Conta Forti de serviço (não pool mentors) + XOR Mac/VPS | P1 | ops |
| C5 | Apply WG via API do console frágil (break-glass script 72) | P1 | code+ops |
| C6 | Higiene lab (`ARCHGATE_LAB`, root OpenBao residual) | P1 | ops |
| C7 | A1.5 isolamento + A1.6 smoke-evidence datada pendentes | P0 | uat |
| C8 | Orch/oracle/agent defaults mock — **não** bloqueiam v1 bastion | residual | code |

### 1.2 Admin — ArchGate Manager (`_archguard/archguard-console`)

| ID | Achado | Severidade | Tipo |
|----|--------|------------|------|
| A-OK | Sites SoT, wizard, apply, platform, BFF Connect, lifecycle UI | — | ok |
| A1 | `grantPersonTargetFn` só chama orch (mock default) → grant **falso positivo** | P0 code | code |
| A2 | Apply WG admin API instável no lab → scripts 71–73 | P1 | ops+code |
| A3 | `kanidm-proxy` só `requireSession` — viewer pode mutar IAM via SA | P0 code | code |
| A4 | Offboard: expire Kanidm forte; orch/leases best-effort | P1 | code |
| A5 | Tenant admin sem `sites:create` / `gateways:manage` | P2 | product |
| A6 | Path deploy docs `archguard/` vs código em `_archguard/` | P1 | ops |
| A7 | Secrets VPN/SSH still one-shot do cliente | P1 | data |

### 1.3 Connect (`clients/archgate-connect`)

| ID | Achado | Severidade | Tipo |
|----|--------|------------|------|
| K-OK | CLI+desktop+SSO+H6 lab evidenciado 2026-07-19/20 | — | ok |
| K1 | Working tree: `catalog.go` usa `strings` **sem import** → build FAIL | P0 | code |
| K2 | Comando `manager` WIP (diff local) | P1 | code |
| K3 | Notarize / Developer ID | residual | org |
| K4 | `oidc.env` + senha WG por máquina | P0 setup | ops |
| K5 | RDP/DB embutidos incompletos | residual | product |

### 1.4 Drift documental

- `PLAN-HOMOLOGACAO-MVP` ainda marca peer H2 blocked; sprint devops já tem A1.2–A1.4 SSH.
- Residual Sprint1 checklist “OIDC Connect” superado por evidence SSO E2E.

---

## 2. Plano de execução (sprints curtos)

### Sprint F0 — Código hard blockers (este ciclo)

| ID | Tarefa | Repo | Aceite |
|----|--------|------|--------|
| **F0.1** | Fix compile Connect + estabilizar `archgate manager` + tests | archgate | `go test ./...` PASS |
| **F0.2** | RBAC server no `kanidm-proxy` (method+path → permission) | archguard-console | unit tests + deny viewer mutation |
| **F0.3** | Grant target **live no Warpgate** (ensure user + bind role), orch best-effort | archguard-console | grant ok se WG admin OK mesmo com orch mock |
| **F0.4** | Registrar este plano + atualizar residual first-use | archgate docs | arquivo versionado |

### Sprint F1 — Ops first-use Rio (humano / VPS)

| ID | Tarefa | Aceite |
|----|--------|--------|
| **F1.1** | E2E SSH `uat-op-a:rio-aws-api-b` + evidence | smoke-evidence datada |
| **F1.2** | authorized_keys gestor **ou** waiver LAN | evidence ou waiver §6.2 |
| **F1.3** | Secrets PG targets **ou** waiver DB day-1 | evidence ou waiver |
| **F1.4** | UAT runbook ≤30 min + assinar §6.2 | assinatura |
| **F1.5** | oidc.env + users WG nas máquinas piloto | Connect login SSO |

### Sprint F2 — Hardening admin (pós v1)

| ID | Tarefa |
|----|--------|
| **F2.1** | Estabilizar login admin WG API (cookie/SNI) — eliminar script 72 no happy path |
| **F2.2** | Offboard revoga leases OpenBao + Guac local best-effort unificado |
| **F2.3** | Doc path `_archguard` nos scripts deploy |
| **F2.4** | `ORCH_MODE=live` calibrado (B5) |
| **F2.5** | Notarize Connect quando Apple Developer ID |

### Estacionamento (não v1)

UnifiedUI OIDC lab, Oracle JDBC real, NetBird, HA Raft, agent-control live, SIEM.

---

## 3. Definition of Done — 1ª versão de uso

- [x] F0.1 Connect compila e testa
- [x] F0.2 kanidm-proxy deny-by-default perms
- [x] F0.3 grant Warpgate real no Manager
- [ ] F1.1–F1.4 ops/UAT (humano)
- [ ] Operador piloto 1 dia sem VPN cliente (H6 lifestyle)

---

## 4. Tracking de implementação

| Data | Entrega |
|------|---------|
| 2026-07-24 | **F0.1** Connect: fix `strings` import, `manager` CLI, tests |
| 2026-07-24 | **F0.2** Manager: RBAC em `kanidm-proxy` (`requiredPermsForKanidmProxy`) |
| 2026-07-24 | **F0.3** Manager: grant live via Warpgate ensure user + bind role |
| 2026-07-24 | **F0.4** Este plano versionado |

Ver também: [`PLAN-IMPLEMENTACAO-RESTANTE.md`](./PLAN-IMPLEMENTACAO-RESTANTE.md), [`PLAN-HOMOLOGACAO-MVP.md`](./PLAN-HOMOLOGACAO-MVP.md), `archgate-devops/docs/RESIDUAL-SPRINT1.md`.

**Validação Rio Quality (checklist por tipo de acesso):** [`runbooks/sites/VALIDACAO-RIO-QUALITY.md`](./runbooks/sites/VALIDACAO-RIO-QUALITY.md).
