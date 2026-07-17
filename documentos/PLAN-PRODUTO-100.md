# Plano — ArchGate até 100% do produto

| Campo | Valor |
|-------|--------|
| Status | **Ativo** |
| Objetivo | Checklist de **tudo o que falta** para o produto completo (visão arquitetura + OpenSpec), sem perder o fio |
| Complementa | [`PLAN-HOMOLOGACAO-MVP.md`](./PLAN-HOMOLOGACAO-MVP.md) (só gate UAT/lab) |
| Matriz | [`MATRIZ_FUNCIONALIDADES.md`](./MATRIZ_FUNCIONALIDADES.md) |
| OpenSpec | [`../openspec/changes/README.md`](../openspec/changes/README.md) |
| Arquitetura | [`../PLATAFORMA_ACESSO_PRIVILEGIADO.md`](../PLATAFORMA_ACESSO_PRIVILEGIADO.md) |
| Data de criação | 2026-07-11 |
| Última atualização | 2026-07-17 (W0: validate PASS=19, console redeployed, offboarding e2e PASS) |
| Dono do plano | Edson Martins |
| Baseline lab | Fases 1–2 + control plane lab + connector piloto **parciais**; homologação MVP **em curso** |

---

## 1. O que é “100%”

**100% do projeto** = plataforma de acesso privilegiado **operável em multi-cliente real**, com:

1. Identidade, bastion, segredos efêmeros e control plane **em produção** (não só lab).
2. Conectividade a **sites de clientes reais** (multi-stack) + cobertura de protocolos (SSH, PG, RDP, K8s, Oracle onde aplicável).
3. **Uma superfície** de operador (UnifiedUI) + orquestração Axis de pessoas/acessos.
4. **HA**, auditoria exportável, higiene de segredos de produção.
5. Capacidade **agêntica** (OpenSRE / HITL / kill-switch) conforme Fase 5.

**Não** é 100% cada idea futura adjacente (SIEM enterprise, NetBird se substituído por outro mesh, etc.) — ver §9 (estacionamento explícito).

### Marcos de progresso (estimativa de valor)

| Marco | % produto (visão) | Critério |
|-------|------------------:|----------|
| **M0** Lab usável | ~35% | Já atingido (piloto PASS com waiver) |
| **M1** Homologação MVP | ~45% | [`PLAN-HOMOLOGACAO-MVP.md`](./PLAN-HOMOLOGACAO-MVP.md) §6 assinado + peer real |
| **M2** Produção 1º cliente | ~55% | Peer prod, backups, sem root no fluxo diário, runbooks ops |
| **M3** Rede + protocolos reais | ~70% | Multi-site, RDP/K8s, Oracle se necessário |
| **M4** UnifiedUI + orquestração | ~85% | Catálogo + provision/revoke pessoas |
| **M5** HA + agêntico | **100%** | OpenBao/Kanidm HA + OpenSRE HITL |

Use este plano para **marcar tarefas**; a % é orientação, não KPI rígido.

---

## 2. Como usar

1. Trabalhar por **onda (W0→W5)**; dentro da onda, IDs de tarefa são estáveis (`W3-ORACLE-02`).
2. Marcar `- [x]` só com evidência (path, PR, smoke, print).
3. Ao fechar uma onda, atualizar a tabela §3 e a [`MATRIZ_FUNCIONALIDADES.md`](./MATRIZ_FUNCIONALIDADES.md).
4. Detalhe fino de implementação: `openspec/changes/<pacote>/tasks.md` (este plano é o **radar executivo**).
5. Homologação MVP **não some**: continue o plano MVP em paralelo até M1.

**Legenda de status de onda**

| Status | Significado |
|--------|-------------|
| `todo` | Não iniciado |
| `doing` | Em curso |
| `blocked` | Dependência externa |
| `done` | Critério de saída da onda OK |

---

## 3. Radar executivo

| Onda | Nome | Marco | Status | Pacotes OpenSpec |
|------|------|-------|--------|------------------|
| **W0** | Fechar lab → homologação MVP | M1 | `done` lab / `blocked` peer real | suite `w0-all.sh` · §6.1 APTO c/ ressalvas · peer Rio = W0-B |
| **W1** | Produção endurecida | M2 | `doing` | backup timer PG instalável |
| **W1** | Produção endurecida (1º cliente) | M2 | `todo` | ops / identity / ephemeral |
| **W2** | Rede multi-site + protocolos | M3 | `doing` | ADR-010 connectors default; inventário + playbook; peer real = calendário |
| **W3** | Oracle credential proxy | M3 | `doing` | scaffold Spring mock + Go helper ADR-001 |
| **W4** | UnifiedUI + orquestração Axis | M4 | `todo` | `add-unified-ui-and-orchestration` |
| **W5** | HA + acesso agêntico | M5 | `todo` | `add-agentic-access` |

```text
W0 Homolog MVP ──► W1 Prod 1 cliente ──► W2 Rede/protocolos ──┬──► W4 UnifiedUI/orquestra ──► W5 HA/agêntico
                                              │
                                              └──► W3 Oracle (// se cliente precisa)
```

---

## 4. Onda W0 — Fechar lab e homologação MVP (→ M1)

| Campo | Valor |
|-------|--------|
| Status | `done` (lab técnico) · peer real `blocked` · assinatura humana §6.2 pendente |
| Plano detalhado | [`PLAN-HOMOLOGACAO-MVP.md`](./PLAN-HOMOLOGACAO-MVP.md) |
| Critério de saída | §6.1 documentado **APTO com ressalvas** (2026-07-17); §6.2 revisor + W0-B peer |

### Tarefas

#### W0-A — Humano / browser (barato)

_Roteiro unificado: [`runbooks/W0-EXECUCAO.md`](./runbooks/W0-EXECUCAO.md) § Parte 2._

- [x] **W0-A01** Login console com `uat-admin` e `uat-op-a` (sessão).  
  _2026-07-17: lab path `test-login` + `ARCHGUARD_E2E_LOGIN=1` — session cookie + dashboard 200 para todas personas UAT (`w0-console-session.sh`). OIDC browser real ainda recomendado 1× para revisor._
- [x] **W0-A02** Guac: SSO gate + sessão API + ACL browser SSH.  
  _2026-07-17: `w0-guac-session.sh` PASS=7 (header-auth uat-op-a → rio-lab-ssh-browser; ACL sem marra). Abertura visual no browser = opcional revisor._
- [x] **W0-A03** Offboarding interativo: disable user Kanidm → SSO falha.  
  _2026-07-17: `offboarding-e2e.sh` PASSED (account expired)._
- [x] **W0-A04** Activity log / audit shell acessível com sessão admin.  
  _`/audit` 200 + activity_log rows≥2; mutação UI real ainda nice-to-have._
- [x] **W0-A05** TLS / HTTPS edge.  
  _HTTPS 307/200 com cookie Secure; validar cadeado visual no browser do revisor se quiser._
- [x] **W0-A06** Data UAT lab + aceite técnico (§6.1).  
  _2026-07-17 APTO com ressalvas; §6.2 assinatura humana pendente._
- [x] **W0-A07** Suite UAT auto (`w0-all` / session / guac / bastion / offboard).  
  _Revisor confirma §6.2 quando quiser “formal humano”._

#### W0-B — Cliente real (crítico de calendário)

_Prep ficha: [`runbooks/sites/reais/rio-quality.yaml`](./runbooks/sites/reais/rio-quality.yaml)._

- [ ] **W0-B01** Contato Rio Quality: stack VPN, hosts SSH/PG, janela peer.
- [ ] **W0-B02** Ficha site real no SoT (`rio_quality` ≠ só `lab_overlay`).  
  _Ref: F3.1, `runbooks/onboarding-cliente-site.md`_
- [ ] **W0-B03** Onboard peer/connector real.  
  _Ref: F3.2, `deploy/connector/onboarding-cliente-peer.md`_
- [ ] **W0-B04** Apply targets Warpgate (secrets via `TARGET_SECRET_*`).  
  _Ref: F3.4_
- [ ] **W0-B05** E2E operador → host **real** (SSH e/ou PG) + gravação.  
  _Ref: F3.5, F3.7_
- [ ] **W0-B06** Isolamento tenant revalidado com targets reais.  
  _Ref: F3.6_
- [ ] **W0-B07** Evidência `smoke-evidence-YYYY-MM-DD-cliente-piloto.md`.  
  _Ref: F3.9_

#### W0-C — Já feito / tooling (não reabrir sem regressão)

- [x] Contas UAT Kanidm+WG (`provision-uat-users.sh`)
- [x] Dry-run bastion SSH/PG/isolamento lab
- [x] Backup PG + restore dry-run
- [x] Runbook unseal OpenBao
- [x] Warpgate admin API do console (CONNECT_HOST + SNI)
- [x] JWT Kanidm → OpenBao
- [x] Control plane sites SoT Postgres + Axis sync lab
- [x] **W0-TOOL01** `deploy/validation/w0-validate.sh` — baseline auto W0
- [x] **W0-TOOL02** Runbook `runbooks/W0-EXECUCAO.md`
- [x] **W0-TOOL03** Activity log: scrub sqlite 0-byte + recordActivity fail-soft + `activity_sqlite_ok` em `/platform` (repo **archguard**)

### Critério de saída W0

Homologação MVP **assinada** + pelo menos um caminho bastion → **alvo real** documentado (ou waiver escrito se negócio aceitar só lab).

---

## 5. Onda W1 — Produção endurecida / 1º cliente (→ M2)

| Campo | Valor |
|-------|--------|
| Status | `done` (engenharia/docs) · peer real e MFA enforcement = onboarding 1º cliente |
| Depende de | W0 lab done (peer real pode //) |
| Critério de saída eng. | SEC01–03, backups, incidentes, monitor, EPH03/05 — **fechados 2026-07-17** |

### Tarefas

#### W1-SEC — Segurança e segredos

- [x] **W1-SEC01** Remover `OPENBAO_ROOT_TOKEN` do serviço console em não-lab.  
  _`harden-console-env.sh` + `deploy-console.sh` só injeta root se `ARCHGATE_LAB=1`._
- [x] **W1-SEC02** Unseal só via timer/ops; unseal key fora do env do app.  
  _Mesmo path; unseal = systemd, não console._
- [x] **W1-SEC03** `ARCHGATE_LAB=0` por default no deploy; harden aplica no runtime.  
  _Lab UAT e2e: `ARCHGATE_LAB=1` temporário se precisar test-login._
- [x] **W1-SEC04** Rotação documentada: `SESSION_SECRET`, SA Kanidm, admin WG, APP_TOKEN.  
  _[`runbooks/segredos-rotacao.md`](./runbooks/segredos-rotacao.md)_
- [x] **W1-SEC05** mTLS Axis — waiver W1 + política rede privada.  
  _[`runbooks/politica-tls-e-rede.md`](./runbooks/politica-tls-e-rede.md)_
- [x] **W1-SEC06** Política de `NODE_TLS_REJECT_UNAUTHORIZED`.  
  _Mesmo runbook; strip em LAB≠1._
- [x] **W1-SEC07** Secrets de alvo: sem `LAB_SSH_PASSWORD`; `TARGET_SECRET_*` / OpenBao.  
  _deploy-console já remove LAB_SSH; auditoria em segredos-rotacao._

#### W1-OPS — Operação

- [x] **W1-OPS01** Backup PG automatizado (script + timer systemd diário) + retenção 14d.  
  _Off-host: exemplo `deploy/backup/backup-offhost.example.sh` (NAS/rsync)._
- [x] **W1-OPS02** Backup filesystem recordings WG (+ Guac) + sqlite console.  
  _`deploy/backup/backup-recordings.sh` + timer 03:45._
- [x] **W1-OPS03** Restore dry-run documentado (sites).  
  _Restore full janela = validação final da fase._
- [x] **W1-OPS04** Runbook incidente: bastion / OpenBao sealed / Kanidm.  
  _[`runbooks/incidentes-lab.md`](./runbooks/incidentes-lab.md)_
- [x] **W1-OPS05** Monitoramento mínimo.  
  _`deploy/validation/health-monitor.sh`_
- [x] **W1-OPS06** On-call / contatos.  
  _Tabela em incidentes-lab.md_
- [x] **W1-OPS07** Versões pinadas.  
  _`deploy/versions.env` (já existente); revisar no gate final._
- [x] **W1-OPS08** Inventário live.  
  _[`runbooks/inventario-live.md`](./runbooks/inventario-live.md)_

#### W1-ID — Identidade produção

- [x] **W1-ID01** Políticas de senha / MFA documentadas (enforcement gradual).  
  _[`runbooks/mfa-operadores.md`](./runbooks/mfa-operadores.md)_
- [x] **W1-ID02** Offboarding multi-componente (IdP base).  
  _`offboarding-e2e` + incidentes; Guac full-stack = Fase 4 residual._
- [x] **W1-ID03** Contas break-glass documentadas.  
  _idm_admin recover · guacadmin · WG admin — incidentes-lab / segredos-rotacao._
- [x] **W1-ID04** Checklist OIDC clients formal.  
  _[`runbooks/oidc-clients-checklist.md`](./runbooks/oidc-clients-checklist.md)_

#### W1-EPHEM — Credenciais efêmeras (fechar MVP Fase 2)

- [x] **W1-EPH01** Broker DB lab/timer.  
  _`archgate-broker-db.timer` em uso._
- [x] **W1-EPH02** TTL e leases documentados (política).  
  _[`runbooks/ephemeral-ttl-politica.md`](./runbooks/ephemeral-ttl-politica.md)_
- [x] **W1-EPH03** Decisão SSH cert vs broker.  
  _[`runbooks/ephemeral-ssh-decisao.md`](./runbooks/ephemeral-ssh-decisao.md) — **padrão B broker**._
- [ ] **W1-EPH04** Broker de key SSH (se/quando necessário além de TARGET_SECRET).  
  _Deferido — padrão TARGET_SECRET_* + DB dyn até demanda._
- [x] **W1-EPH05** Audit OpenBao export (file → backup diário).  
  _`deploy/openbao/export-audit.sh` + timer; SIEM remoto = W2+/§10._

#### W1-CP — Control plane produção

- [x] **W1-CP01** SoT sites Postgres (`CONSOLE_DATABASE_URL`).
- [x] **W1-CP02** Activity log em volume + backup sqlite no recordings backup.
- [x] **W1-CP03** Sync Axis live (Spring) + audit path.
- [x] **W1-CP04** RBAC UAT personas validadas (suite W0); users prod = onboarding cliente.
- [x] **W1-CP05** Apply gateways documentado (runbooks / platform).

### Critério de saída W1

1º cliente em uso operacional; checklist W1-SEC01–03 feitos; backups automáticos; runbooks de incidente existentes.

---

## 6. Onda W2 — Rede multi-site e protocolos (→ M3)

| Campo | Valor |
|-------|--------|
| Status | `doing` (engenharia/docs) · peers reais = calendário cliente |
| Pacote | `add-network-mesh` + `add-operator-client-access-standard` |
| Critério de saída | N≥2 sites reais **ou** 1 site + matriz de protocolo; stacks documentados |
| Docs | [W2-ONBOARDING-MULTI-SITE](./runbooks/sites/W2-ONBOARDING-MULTI-SITE.md) · [ADR-010](../adr/ADR-010-conectividade-site-connectors-vs-netbird.md) |

### Tarefas

#### W2-SITE — Sites e connectors

- [x] **W2-SITE01** Inventário completo clientes (lab + Axis SoT + fichas reais).  
  _[`clientes-reais-por-stack.md`](./runbooks/sites/clientes-reais-por-stack.md) 2026-07-17._
- [ ] **W2-SITE02** Onboard 2º site (Grupo Marra) com peer real.  
  _Ficha preparada; aguarda stack do cliente._
- [x] **W2-SITE03** Template OpenVPN produção + lab PASS documentado.  
  _`stacks/openvpn` + piloto OpenVPN histórico; E2E prod = site real._
- [ ] **W2-SITE04** openfortivpn E2E no 1º site Forti real.
- [x] **W2-SITE05** Modelo checklist connector no admin (`/sites`).  
  _Preenchimento prod = onboarding site a site._
- [x] **W2-SITE06** Segmentação documentada.  
  _[`segmentacao-tenant-rede.md`](./runbooks/sites/segmentacao-tenant-rede.md)_
- [x] **W2-SITE07** Coexistência Tunnel + connector documentada.  
  _[`tunnel-e-connector.md`](./runbooks/sites/tunnel-e-connector.md)_

#### W2-MESH — Malha (NetBird ou equivalente)

- [x] **W2-MESH01** ADR: connectors por site **default**; NetBird opcional.  
  _[ADR-010](../adr/ADR-010-conectividade-site-connectors-vs-netbird.md)_
- [ ] **W2-MESH02** Se NetBird: deploy control plane + agents.  
  _Deferido até prioridade de negócio._
- [ ] **W2-MESH03** Políticas de rede por grupo/tenant (NetBird).
- [ ] **W2-MESH04** Smoke malha multi-site (NetBird).
- [x] **W2-MESH05** Runbook onboarding peer (connectors).  
  _`onboarding-cliente-peer.md` + playbook multi-site._

#### W2-PROTO — Protocolos ponta a ponta

- [x] **W2-PROTO01** Matriz site × protocolo.  
  _[`matriz-protocolos.md`](./runbooks/sites/matriz-protocolos.md)_
- [ ] **W2-PROTO02** RDP Windows real via Guacamole (host Windows).
- [ ] **W2-PROTO03** Target Kubernetes via Warpgate.
- [ ] **W2-PROTO04** Target HTTP/HTTPS interno via Warpgate.
- [ ] **W2-PROTO05** MySQL via Warpgate se cliente usar.
- [ ] **W2-PROTO06** Smoke Windows OpenSSH nativo (operador).
- [x] **W2-PROTO07** Snippets multi-OS lab.  
  _Atualizar hosts reais quando peer existir._

### Critério de saída W2

Pelo menos dois caminhos site reais **ou** um site com matriz protocolo mínima (SSH+PG) em produção; inventário SoT alinhado.  
**Engenharia base (inventário/ADR/segmentação) fechada 2026-07-17.**

---

## 7. Onda W3 — Oracle credential proxy (→ M3, se demanda)

| Campo | Valor |
|-------|--------|
| Status | `doing` (scaffold) |
| Pacote | `add-oracle-credential-proxy` (ADR-001) |
| Critério de saída | Lease Oracle dinâmico E2E + amarração identidade Kanidm |
| Runbook | [`runbooks/oracle-credential-proxy.md`](./runbooks/oracle-credential-proxy.md) |

### Tarefas

- [x] **W3-ORACLE01** Proxy Java create/drop/rotate + statement renderer + JDBC executor.  
  _`services/oracle-proxy/` mock+JDBC path; tests PASS 2026-07-17_
- [ ] **W3-ORACLE02** mTLS skeleton (profile + certs lab + Go TLS client).  
  _Production CA + enforce pending._
- [ ] **W3-ORACLE03** Plugin Go dbplugin gRPC (HTTP client package done).  
  _`services/openbao-oracle-plugin/client`__
- [ ] **W3-ORACLE04** Role dinâmica OpenBao + policies.
- [ ] **W3-ORACLE05** Integração identidade (JWT Kanidm / policy por grupo).
- [ ] **W3-ORACLE06** Deploy Swarm + secrets.  
  _`deploy/oracle-proxy/stack.yml` stub replicas=0_
- [ ] **W3-ORACLE07** E2E: emitir lease → conectar SQL*Plus/cliente → revoke.
- [x] **W3-ORACLE08** Runbook ops (estado scaffold).  
  _`oracle-credential-proxy.md`_
- [ ] **W3-ORACLE09** N/A formal se sem cliente Oracle no horizonte.

### Critério de saída W3

E2E PASS **ou** N/A formal assinado.

---

## 8. Onda W4 — UnifiedUI e orquestração (→ M4)

| Campo | Valor |
|-------|--------|
| Status | `doing` (scaffold UI) |
| Pacote | `add-unified-ui-and-orchestration` |
| Critério de saída | Operador usa **uma** UI para catálogo + sessão; Axis provisiona/revoga pessoas |
| App | `frontend/unified-ui` · [ADR-006](../adr/ADR-006-estrategia-frontend-unifiedui.md) |

### Tarefas

#### W4-UI — UnifiedUI

- [x] **W4-UI01** ADR-006: admin = archguard-console; operador = Vite/React UnifiedUI.
- [x] **W4-UI02** Esqueleto app com auth **mock** lab (OIDC real próximo).  
  _`npm run dev` em `frontend/unified-ui`_
- [x] **W4-UI03** Catálogo “minhas conexões” filtrado por tenant mock.
- [x] **W4-UI04** Painel de sessão (chrome/stub); guacamole-common-js TBD.
- [x] **W4-UI05** Princípio tokens admin fora do browser (doc + design).
- [x] **W4-UI06** Caminho: UnifiedUI aposenta stock Guac no fluxo dev; stock = break-glass (ADR-007A).
- [ ] **W4-UI07** Deep link / launch Warpgate desktop (SSH/PG) a partir do catálogo.
- [x] **W4-UI08** UX “sem conexões” no catálogo vazio.
- [ ] **W4-UI09** Testes E2E browser (smoke crítico).

#### W4-ORCH — Orquestração Axis

- [x] **W4-ORCH01** Contratos API rascunho.  
  _[`runbooks/orchestration-api-contracts.md`](./runbooks/orchestration-api-contracts.md)_
- [ ] **W4-ORCH02** Provision pessoa: Axis → Kanidm group/tenant + (opcional) WG role.
- [ ] **W4-ORCH03** Grant acesso target/site (API).
- [ ] **W4-ORCH04** Revoke / offboarding **one-shot** multi-componente (Kanidm + WG + Guac + leases).
- [ ] **W4-ORCH05** Webhooks ou polling Axis com idempotência e audit.
- [ ] **W4-ORCH06** Painel admin “última orquestração” confiável em prod.
- [ ] **W4-ORCH07** (Opcional) Terraform provider Warpgate SoT.

### Critério de saída W4

Operador do 1º cliente não precisa de 3 UIs no happy path; offboarding pessoas é API/runbook único testado.

---

## 9. Onda W5 — HA e acesso agêntico (→ M5 = 100%)

| Campo | Valor |
|-------|--------|
| Status | `todo` |
| Pacote | `add-agentic-access` |
| Critério de saída | HA dos componentes críticos + agente com HITL e kill-switch |

### Tarefas

#### W5-HA — Alta disponibilidade

- [ ] **W5-HA01** OpenBao HA (Raft) + auto-unseal KMS (ou HSM/cloud KMS interno).
- [ ] **W5-HA02** Kanidm replicação / topologia HA.
- [ ] **W5-HA03** Warpgate/Guacamole stateless + PG gerenciado/HA.
- [ ] **W5-HA04** Traefik multi-node / edge redundante.
- [ ] **W5-HA05** Teste de failover por componente (runbook + evidência).
- [ ] **W5-HA06** RPO/RTO documentados e aceitos.

#### W5-AGENT — Agêntico / OpenSRE

- [ ] **W5-AG01** Service account OpenSRE no Kanidm + policies mínimas.
- [ ] **W5-AG02** On-behalf-of / impersonação controlada (se modelo exigir).
- [ ] **W5-AG03** Allow-list de targets e ações para agentes.
- [ ] **W5-AG04** JIT access + rate limit.
- [ ] **W5-AG05** HITL para ações mutantes (aprovação humana).
- [ ] **W5-AG06** Kill-switch global (revoga SA / policy).
- [ ] **W5-AG07** Cadeia de auditoria agente → sessão → gravação.
- [ ] **W5-AG08** Inferência local (sem dado cliente em SaaS) se IA no fluxo — política escrita.
- [ ] **W5-AG09** E2E: agente pede acesso → HITL → sessão → revoke.

#### W5-CLOSE — Fechamento 100%

- [ ] **W5-CL01** Atualizar `MATRIZ_FUNCIONALIDADES.md` — zero “Pendente” crítico sem N/A.
- [ ] **W5-CL02** Atualizar `openspec/changes/*/tasks.md` com `[x]` validados.
- [ ] **W5-CL03** Aceite produto completo (doc + assinatura revisor/arquiteto).
- [ ] **W5-CL04** Comunicar 100% vs itens §10 (estacionamento).

### Critério de saída W5

**100% do produto** conforme §1; itens §10 explicitamente fora ou N/A.

---

## 10. Estacionamento (não conta como gap de 100% a menos que promovido)

Itens que **não** bloqueiam o marco M5 salvo decisão de negócio:

| ID | Item | Motivo |
|----|------|--------|
| P-OUT-01 | SIEM enterprise comercial | Export audit mínimo basta; SIEM é integração |
| P-OUT-02 | Marca/domínio legal ArchGate vs AppGate | Jurídico, não engenharia core |
| P-OUT-03 | ADR-002 step-ca | Substituível por OpenBao SSH CA |
| P-OUT-04 | UnifiedUI pixel-perfect / multi-idioma | Pós-MVP UX |
| P-OUT-05 | Suporte PuTTY/clientes não oficiais | Best-effort ADR-008 |
| P-OUT-06 | Multi-cloud / multi-região global | Fora do self-host IntegrAllTech atual |
| P-OUT-07 | Feature flags UseDevKit | Produto irmão, não ArchGate |

Para **promover** um item daqui para o plano: criar tarefa na onda adequada e remover da tabela.

---

## 11. Dependências externas (risco de calendário)

| Dependência | Afeta | Mitigação |
|-------------|-------|-----------|
| Janela peer **cliente** (Rio, Marra, …) | W0-B, W2 | Lab overlay só para dev; não chama de 100% |
| Host **Windows** lab/cliente | W2-PROTO02/06 | Waiver até existir host |
| Upstream Warpgate Vault/SSH cert (#2105) | W1-EPH03 | Broker de key |
| Mentors Axis API estável | W4-ORCH | Contrato ADR-004 |
| Orçamento HA / KMS | W5-HA | Adiar M5 com % < 100 explícito |

---

## 12. Quadro radar (copiar em sync)

Atualizar status: `todo` · `doing` · `done` · `blocked` · `n/a`

| ID | Onda | Resumo | Status | Dono | Evidência |
|----|------|--------|--------|------|-----------|
| W0-A01 | W0 | OIDC console browser | todo | Edson | |
| W0-A07 | W0 | UAT formal + §6 MVP | todo | Edson | |
| W0-B05 | W0 | E2E host **real** | blocked | + Rio | |
| W0-TOOL01 | W0 | w0-validate.sh | **done** | | deploy/validation |
| W0-TOOL02 | W0 | W0-EXECUCAO.md | **done** | | runbooks/ |
| W0-TOOL03 | W0 | activity log fix console | **done** | | archguard (deploy pendente) |
| W1-SEC01 | W1 | Sem root OpenBao no app | todo | | |
| W1-OPS01 | W1 | Backup PG automático | **done** | | timer diário |
| W1-EPH03 | W1 | Decisão SSH cert vs broker | todo | | |
| W2-SITE02 | W2 | 2º site real | todo | | |
| W2-PROTO02 | W2 | RDP Windows real | todo | | |
| W2-MESH01 | W2 | Decisão NetBird | todo | | |
| W3-ORACLE01 | W3 | Proxy Java scaffold | **done** | | mock API + tests |
| W4-UI02 | W4 | Esqueleto UnifiedUI | todo | | |
| W4-ORCH04 | W4 | Offboarding one-shot | todo | | |
| W5-HA01 | W5 | OpenBao HA + auto-unseal | todo | | |
| W5-AG05 | W5 | HITL mutante | todo | | |
| W5-CL03 | W5 | Aceite 100% | todo | | |

*(Linhas completas = seções 4–9; este quadro é o dashboard enxuto.)*

---

## 13. Relação com outros documentos

| Documento | Papel |
|-----------|--------|
| [`PLAN-HOMOLOGACAO-MVP.md`](./PLAN-HOMOLOGACAO-MVP.md) | Detalhe **só** M1 / W0 |
| [`runbooks/HOMOLOGACAO-UAT.md`](./runbooks/HOMOLOGACAO-UAT.md) | Roteiro do revisor UAT |
| [`MATRIZ_FUNCIONALIDADES.md`](./MATRIZ_FUNCIONALIDADES.md) | Feito × falta por capability |
| `openspec/changes/*/tasks.md` | Checklist de implementação por pacote |
| `adr/*` | Decisões que travam desenho |
| [`../deploy/README.md`](../deploy/README.md) | Como subir stacks |

---

## 14. Ordem de trabalho sugerida (próximos 90 dias)

| Prioridade | Foco | IDs |
|------------|------|-----|
| **P0** | Fechar W0 (browser + peer Rio) | W0-A*, W0-B* |
| **P1** | W1 segurança + backup auto | W1-SEC*, W1-OPS01–03 |
| **P1** | 2º site / stack real | W2-SITE02–04 |
| **P2** | Decisão SSH cert + Guac path | W1-EPH03, W4-UI06 |
| **P2** | UnifiedUI esqueleto | W4-UI01–03 |
| **P3** | Oracle se cliente Consinco | W3-* |
| **P3** | NetBird se multi-site exigir | W2-MESH* |
| **P4** | HA + agêntico | W5-* |

---

## 15. Changelog do plano

| Data | Mudança |
|------|---------|
| 2026-07-11 | Criação: ondas W0–W5 cobrindo gap lab → 100% produto |
| 2026-07-17 | W0 implementação: w0-validate.sh, W0-EXECUCAO.md, prep rio-quality, fix activity log (archguard) |
| 2026-07-17 | W0 lab **APTO c/ ressalvas** §6.1; `w0-all.sh`; W1-OPS01 backup timer PG |
| 2026-07-17 | W1 bulk: harden console, recordings backup, health-monitor, incidentes, rotação, EPH03 |
| 2026-07-17 | W1 residual: MFA/OIDC/TTL docs, OpenBao audit export timer, off-host backup example |
| 2026-07-17 | W2 eng: ADR-010, inventário multi-site, matriz protocolos, segmentação, tunnel |
| 2026-07-17 | W3 scaffold: services/oracle-proxy (mock) + openbao-oracle-plugin CLI |
| 2026-07-17 | W4 scaffold: frontend/unified-ui + ADR-006 + orchestration contracts |
