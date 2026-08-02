# ArchGate — Matriz de funcionalidades

**Data de referência:** 2026-08-02 (ADR-014 — IdP passa a ser o ArchGuard)  
**Ambiente validado:** lab/staging (`192.168.1.180`, Swarm)  
**Fonte de verdade por pacote:** `openspec/changes/*/tasks.md`  
**Plano do que falta até 100%:** [`PLAN-PRODUTO-100.md`](./PLAN-PRODUTO-100.md) · Homologação MVP: [`PLAN-HOMOLOGACAO-MVP.md`](./PLAN-HOMOLOGACAO-MVP.md)

Legenda de status:

| Símbolo | Significado |
|---------|-------------|
| **Feito** | Implementado e validado no lab (smoke/E2E ou aceite documentado) |
| **Parcial** | Existe no lab com gap conhecido (workaround, waiver ou escopo reduzido) |
| **Pendente** | Não implementado ou só desenhado |
| **Bloqueado** | Dependência externa / ADR / pacote futuro |

---

## 1. Resumo por fase / pacote OpenSpec

| # | Pacote | Fase | Status geral | Feito (lab) | Falta |
|---|--------|------|--------------|-------------|-------|
| 1 | `add-identity-axis` | 1 — Identidade | **Lab complete** | Kanidm, Warpgate SSO, Guac portão SSO, console, multi-tenant, offboarding, audit | Guac 1:1 nativo OIDC; RDP Windows host; UnifiedUI |
| 1b | `add-operator-client-access-standard` | 1 — Padrão operador | **Lab-ready** | ADR-008, runbooks, smoke L+macOS, DB proxy, connector piloto, sites | Windows nativo; VPN cliente real; catálogo UnifiedUI |
| 2 | `add-ephemeral-credentials` | 2 — Credenciais | **MVP lab** | OpenBao, SSH CA, DB dinâmico, broker Warpgate DB, JWT←Kanidm, unseal timer | SSH cert nativo no Warpgate; HA/auto-unseal |
| 3a | `add-oracle-credential-proxy` | 3 — Pré-req Oracle | **Scaffold** | oracle-proxy mock + plugin CLI + mTLS skeleton | JDBC Oracle real + plugin gRPC catalog |
| 3 | `add-network-mesh` | 3 — Rede | **Lab piloto WG** | Dual-network + **WireGuard real** (agent+connector), smoke PASS, checklist 0.5 | NetBird, cliente real, RDP/K8s/Oracle E2E |
| 4 | `add-unified-ui-and-orchestration` | 4 — UI + orquestração | **Scaffold lab** | UnifiedUI + launch WG + guac-common-js + orchestration mock/live dry-run | OIDC/BFF lab, adapters live calibrados, E2E browser |
| 5 | `add-agentic-access` | 5 — HA + agêntico | **Scaffold** | ADR-011/012, HA runbooks, agent-control HITL/kill-switch, OpenBao Raft exemplos | Cluster multi-node, SA live, aceite RPO/RTO |

---

## 2. Matriz por capability

### 2.1 Identidade e SSO (`identity` / `gateway-authentication`)

| Funcionalidade | Status | Evidência / nota |
|----------------|--------|------------------|
| Kanidm como IdP OIDC | **Feito** | `id.archgate.com.br` — substituído pelo ArchGuard (ADR-014) |
| ArchGuard (fork Casdoor) como IdP OIDC | **Código pronto, virada pendente** | `ARCHGATE_IDP=archguard`; smoke `smoke-archguard-cutover.sh` |
| Porto de administração de identidade (2 adapters) | **Feito** | `archguard-console/src/server/idp/` |
| Descoberta OIDC agnóstica de IdP | **Feito** | issuer/JWKS/userinfo vêm do documento |
| Tenants como grupos/escopos | **Feito** | Rio Quality, Grupo Marra, … |
| RBAC papéis ArchGuard | **Feito** | super_admins, tenant_admins, users, service_desk, viewers |
| OIDC clients: console, warpgate, guacamole, openbao | **Feito** | bootstrap + OpenBao JWT |
| Authorization Code + PKCE (clients públicos) | **Feito** | Kanidm; Guac via oauth2-proxy |
| Warpgate SSO Kanidm | **Feito** | operadores sem senha local |
| Guacamole SSO browser (Code+PKCE) | **Parcial** | **ADR-007A** oauth2-proxy na borda; app Guac ainda JDBC/header |
| Guacamole OIDC nativo Code+PKCE | **Pendente** | Guac 1.7+ ou UnifiedUI (ADR-007) |
| Console ArchGuard OIDC + RBAC UI | **Feito** | tenant filter, provision/disable via SA |
| Login único Kanidm → Warpgate + console + portão Guac | **Feito** | Fase 1 6.1 |
| Offboarding: disable Kanidm derruba SSO | **Feito** | `offboarding-e2e` |
| OpenBao auth/jwt ← Kanidm id_token | **Feito** | `smoke-kanidm-jwt.sh` PASS |

### 2.2 Gateways e sessões

| Funcionalidade | Status | Evidência / nota |
|----------------|--------|------------------|
| Warpgate + Postgres externo | **Feito** | não SQLite |
| Targets SSH + Postgres de lab | **Feito** | multi-tenant `rio-*` / `marra-*` |
| Isolamento tenant A ↛ B (Warpgate) | **Feito** | roles + smoke |
| Gravação/replay sessão Warpgate | **Feito** | recordings path + audit E2E |
| Guacamole + guacd + Postgres | **Feito** | |
| Conexão browser SSH lab (Guac) | **Feito** | `lab-ssh-browser` |
| Gravação sessão gráfica Guac | **Feito** | recording-storage |
| RDP Windows real (cliente/lab host) | **Pendente** | host Windows n/a no lab |
| ACL multi-tenant Guacamole | **Feito** | provision users LIST rio vs marra |
| Credencial de alvo não exposta ao dev | **Feito** | proxy no bastion |

### 2.3 Cliente operador e acesso (ADR-008)

| Funcionalidade | Status | Evidência / nota |
|----------------|--------|------------------|
| Padrão bastion-first documentado | **Feito** | ADR-008 + runbooks |
| Clientes oficiais (browser, OpenSSH, DBeaver, …) | **Feito** | snippets versionados |
| SSH operador Linux via Warpgate | **Feito** | smoke PASS |
| SSH operador macOS via Warpgate | **Feito** | smoke PASS |
| SSH operador Windows nativo | **Parcial** | procedimento + waiver; smoke nativo deferred |
| Postgres via Warpgate (L + macOS) | **Feito** | `sslmode=require` |
| SSH web via Guacamole | **Feito** | |
| Inventário de sites + fichas YAML | **Feito** | rio, marra, piloto |
| Preferência 1 VPN site → N operadores | **Feito** | documentado; zero exceções ativas |
| VPN/peer **cliente real** | **Pendente** | template WG; não produção |
| Catálogo unificado de conexões no console | **Bloqueado** | Fase 4 UnifiedUI |

### 2.4 Credenciais efêmeras (OpenBao)

| Funcionalidade | Status | Evidência / nota |
|----------------|--------|------------------|
| OpenBao single-node (file) lab | **Feito** | `deploy/openbao/deploy.sh` |
| Init/unseal keys em bootstrap.env | **Feito** | threshold 1 lab |
| Unseal no deploy + systemd boot | **Feito** | `archgate-openbao-unseal` |
| Unseal periódico pós-recreate | **Feito** | timer **2 min** validado |
| Audit file local | **Feito** | `/var/lib/archgate/openbao/audit` |
| SSH CA + role `lab-user` | **Feito** | TTL 15m |
| Login SSH com cert efêmero (host lab) | **Feito** | `SSH_CERT_LOGIN_OK` |
| Database engine Postgres dinâmico | **Feito** | role `lab-readonly` |
| Create + revoke lease DB | **Feito** | `smoke-ephemeral.sh` |
| Broker OpenBao → target Warpgate DB | **Feito** | rio/lab/marra postgres; timer 20 min |
| Operador DB via Warpgate com user dinâmico | **Feito** | `smoke-broker-warpgate.sh` |
| Emissão amarrada a identidade Kanidm (JWT) | **Feito** | role `archgate-operator` + groups SPN |
| Warpgate pede cert SSH ao OpenBao no connect | **Bloqueado** | upstream warpgate#2105 |
| SSH via Warpgate **somente** com cert CA | **Pendente** | depende de 4.1 / broker de key |
| OpenBao HA + auto-unseal KMS | **Pendente** | Fase 5 / prod |
| SIEM remoto de audit | **Pendente** | lab = file only |

### 2.5 Rede e conectividade de site

| Funcionalidade | Status | Evidência / nota |
|----------------|--------|------------------|
| Padrão dual-network connector | **Feito** | `deploy/connector/README.md` |
| Piloto lab: site isolado + connector | **Feito** | socat legado + **WG** |
| Lab WireGuard (connector fora da site-net) | **Feito** | `deploy-wg-piloto-lab.sh` + smoke PASS 2026-07-11 |
| Template + checklist peer produção | **Feito** | `wireguard-peer.example.conf`, `onboarding-cliente-peer.md` |
| Modelo multi-stack site (OpenVPN / WG / openfortivpn) | **Feito** (doc) | `conectividade-vpn-clientes.md` |
| Lab OpenVPN (client no connector) | **Feito** | `deploy-openvpn-piloto-lab.sh` + smoke PASS 2026-07-11 |
| Unit OpenVPN produção (template) | **Feito** | `stacks/openvpn/systemd/` |
| Scaffold openfortivpn | **Feito** | `stacks/openfortivpn/` (E2E = 1º site Forti) |
| Connector openfortivpn E2E real | **Pendente** | 1º site real Forti |
| NetBird control plane self-hosted | **Pendente** | mesh completo |
| Inventário clientes reais por stack | **Parcial** | YAML + admin `/sites` (SoT **Postgres**; seed/sync populam) |
| Control plane admin / **ArchGate Manager** (estilo AWS) | **Lab complete (CP-0…7)** | **ADR-009** + **ADR-009A** (nome produto); orquestração full pessoas = Fase 4 |
| Aceite piloto lab (definição formal) | **Checklist** | `documentos/runbooks/ACEITE-PILOTO-LAB.md` |
| Módulo Plataforma (saúde stack) | **Feito (lab)** | `/platform` — probes Kanidm/Bao/WG/Guac/Axis/connector + endpoints + runbooks |
| Sites SoT PostgreSQL | **Feito (lab)** | `CONSOLE_DATABASE_URL` → DB `archguard_console`; fallback SQLite |
| Sync Mentors Axis → sites + grupo Kanidm | **Feito (lab Spring)** | Spring `archgate-axis-spring:9030` + MySQL real; `ensureTenantGroup` |
| Sync Mentors Axis → sites | **Feito** | live Spring (stub opcional em :9030) |
| Mentors Axis Spring lab | **Feito** | `deploy/mentors-axis/deploy-spring-lab.sh`; MySQL 3308 + MQTT |
| Admin connector checklist por site | **Feito** | `/sites/$slug` aba Connector + % na lista |
| Sites YAML import/export + audit | **Feito** | Export/Import na lista; activity_log em mutações |
| Admin visual Clientes/Sites | **Feito** | `/sites` + sync Warpgate |
| Admin Gateways Warpgate CRUD | **Feito** | `/gateways` — targets/roles create/delete |
| Admin Guacamole conexões | **Feito** | `/gateways` tab Guacamole list/create/delete |
| Admin OpenBao (segredos) | **Feito** | `/secrets` — health, mounts, JWT, leases, unseal |
| Peer em cliente-piloto **real** | **Pendente** | task 0.5 — preencher stack e onboard |
| Segmentação malha por tenant | **Pendente** | |
| Coexistência Tunnel + malha | **Pendente** | |
| Matriz SSH/RDP/DB/K8s/Web em cliente real | **Pendente** | |

### 2.6 Oracle (ADR-001)

| Funcionalidade | Status | Evidência / nota |
|----------------|--------|------------------|
| ADR-001 aceito (proxy Java ojdbc) | **Feito** (decisão) | sem Instant Client no OpenBao |
| Serviço proxy create/drop/rotate user | **Parcial** | `services/oracle-proxy` mock + tests |
| Plugin Go OpenBao → proxy | **Parcial** | CLI client + mTLS skeleton |
| mTLS plugin↔proxy | **Parcial** | certs lab + profile |
| Role dinâmica Oracle + E2E lease | **Pendente** | Oracle real |
| Amarração a identidade Kanidm | **Pendente** | |

### 2.7 UnifiedUI e orquestração

| Funcionalidade | Status | Evidência / nota |
|----------------|--------|------------------|
| UI React + guacamole-common-js | **Parcial** | `frontend/unified-ui` + embed; BFF token lab TBD |
| Sessão RDP/SSH embutida no console | **Parcial** | chrome + guac client; stock Guac ainda break-glass |
| Catálogo “minhas conexões” + RBAC tenant | **Parcial** | mock + client BFF |
| Token sensível só server-side | **Parcial** | contrato BFF + design W4-UI05 |
| Orquestração Mentors Axis (provision/grant/revoke) | **Parcial** | `services/orchestration` mock + live dry-run + webhooks |
| Autenticação da API de orquestração | **Feito** | token de serviço fail-closed + HMAC no webhook; fora da borda pública (2026-07-29) |
| Onboarding/offboarding one-shot multi-componente | **Parcial** | API mock; adapters live a calibrar |
| Terraform provider Warpgate SoT | **Pendente** | |

### 2.8 HA e acesso agêntico (Fase 5)

| Funcionalidade | Status | Evidência / nota |
|----------------|--------|------------------|
| Postgres externo (Warpgate/Guac) | **Feito** | base para stateless gateway |
| OpenBao HA / Raft | **Parcial** | exemplos + ADR-011; cluster live TBD |
| Kanidm replicação | **Parcial** | topologia doc; deploy TBD |
| Failover por componente | **Parcial** | runbook + checklist docs |
| RPO/RTO documentados | **Parcial** | `ha-rpo-rto.md` (assinatura pendente) |
| Service account OpenSRE + on-behalf-of | **Parcial** | bootstrap script + audit fields |
| Allow-list / JIT / rate limit agente | **Parcial** | policy YAML + agent-control |
| HITL para ações mutantes | **Parcial** | API mock + testes; credencial de aprovador separada da do agente (2026-07-29) |
| Kill-switch + auditoria cadeia | **Parcial** | kill-switch + GET audit; exige credencial de aprovador |
| Autenticação do plano agêntico | **Feito** | `agent_id` vem da credencial, nunca do corpo (2026-07-29) |
| Inferência local (sem dado prod em SaaS) | **Parcial** | política escrita; flag cloud=false |

---

## 3. Infra de plataforma (transversal)

| Item | Status | Nota |
|------|--------|------|
| Docker Swarm + Traefik TLS | **Feito** | staging |
| CI do monorepo (Java + Go + UI + shell) | **Feito** | `.github/workflows/ci.yml` (2026-07-29) |
| CI/E2E do console | **Feito** | typecheck+build+unit verdes; E2E do control plane e do BFF (2026-07-29) |
| Bypasses de lab desligados por padrão no deploy | **Feito** | `ARCHGATE_LAB` / `ARCHGUARD_E2E_LOGIN` / `ARCHGATE_CONNECT_LAB` = 0 (2026-07-29) |
| Bootstrap secrets fora do git | **Feito** | `/root/archgate/bootstrap.env` |
| Domínios id / console / guac / warpgate | **Feito** | lab |
| Scripts deploy + validation E2E | **Feito** | `deploy/**`, `deploy/validation/**` |
| ADRs 001, 005, 006, 007, 007A, 008, 010, 011, 012 | **Feito** (aceitos) | |
| ADR-002 step-ca | **Pendente** | estacionamento / OpenBao SSH CA |
| ADR-004 fronteira ArchGuard × Mentors Axis | **Aceito (lab parcial)** | Spring sync + orchestration scaffold |

---

## 4. Backlog priorizado (o que falta implementar)

Ordem sugerida para continuar o valor de lab → produção:

| Prio | Item | Pacote | Por quê |
|------|------|--------|---------|
| P1 | VPN/peer **cliente real** (lab WG já valida padrão) | network-mesh 0.5 | Fecha conectividade de site de verdade |
| P1 | Smoke Windows nativo (quando houver host) | operator-client 2.5 | Completa multi-OS |
| P2 | RDP Windows de cliente via Guac | network-mesh 4.1 | Persona desktop browser |
| P2 | UnifiedUI esqueleto + catálogo | unified-ui | Uma superfície; resolve dual login Guac |
| P2 | Guac 1.7 Code+PKCE nativo **ou** só UnifiedUI | identity / ADR-007 | Elimina dual session JDBC |
| P3 | Oracle proxy + plugin | oracle-credential-proxy | ADR-001 / clientes Consinco |
| P3 | NetBird + segmentação tenant | network-mesh | Malha multi-site |
| P3 | Warpgate SSH cert nativo ou broker de key | ephemeral 4.1/4.4 | Bloqueio upstream |
| P4 | OpenBao HA + auto-unseal | agentic / prod | Resiliência |
| P4 | Orquestração Axis + offboarding full-stack | unified-ui 3–4 | Operação em escala |
| P5 | Agêntico OpenSRE + HITL + kill-switch | agentic-access | Diferencial operacional |

---

## 5. Contagem rápida (capabilities de produto no lab)

| | Feito | Parcial | Pendente / bloqueado |
|--|------:|--------:|---------------------:|
| Identidade / SSO | 10 | 1 | 1 |
| Gateways / sessões | 8 | 0 | 2 |
| Cliente operador | 9 | 1 | 2 |
| Credenciais efêmeras | 12 | 0 | 4 |
| Rede / site | 3 | 0 | 5 |
| Oracle | 1 (ADR) | 0 | 5 |
| UnifiedUI / orquestração | 0 | 1 | 6 |
| HA / agêntico | 1 | 0 | 8 |

*Contagens aproximadas da §2; use os `tasks.md` para checklist fino.*

---

## 6. Como atualizar esta matriz

1. Marcar tasks em `openspec/changes/<pacote>/tasks.md`.
2. Ajustar a linha correspondente nesta matriz e a data no topo.
3. Se o status do pacote mudar (ex.: Fase 2 “MVP” → “completo”), atualizar também `openspec/changes/README.md`.

**Validadores lab úteis:**

```bash
# Identidade / gateways
bash deploy/validation/console-rbac-e2e.sh
bash deploy/validation/guacamole-sso-proxy-e2e.sh
bash deploy/validation/offboarding-e2e.sh

# Credenciais
bash deploy/openbao/smoke-ephemeral.sh
bash deploy/openbao/smoke-broker-warpgate.sh
bash deploy/openbao/smoke-kanidm-jwt.sh

# Connector
bash deploy/connector/smoke-connector-piloto.sh
```
