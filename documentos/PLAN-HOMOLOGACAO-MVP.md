# Plano — ArchGate pronto para homologação MVP

| Campo | Valor |
|-------|--------|
| Status do plano | **Ativo** |
| Objetivo | Produto **homologável** (UAT interno / cliente piloto), sem confundir com lab nem com produção multi-cliente |
| Baseline lab | Aceite piloto **PASS com waiver** (2026-07-11) — [`runbooks/ACEITE-PILOTO-LAB.md`](./runbooks/ACEITE-PILOTO-LAB.md) |
| Evidência lab | [`runbooks/sites/smoke-evidence-2026-07-11-aceite-piloto.md`](./runbooks/sites/smoke-evidence-2026-07-11-aceite-piloto.md) |
| Matriz de features | [`MATRIZ_FUNCIONALIDADES.md`](./MATRIZ_FUNCIONALIDADES.md) |
| Data de criação | 2026-07-11 |
| Última atualização | 2026-07-11 (F2.1 rascunho UAT) |
| Dono do plano | _definir_ |
| Cliente piloto #1 | _definir (ex.: Rio Quality / Grupo Marra)_ |

---

## 1. Norte (o que “pronto para homologar” significa)

Um revisor (humano) consegue, em **≤ 30 minutos** com o runbook de UAT:

1. Entrar no console via **OIDC Kanidm**.
2. Ver inventário / saúde (`/sites`, `/platform`).
3. Como **operador do tenant A**, abrir **SSH e/ou Postgres** via Warpgate até um alvo **no site do cliente piloto**.
4. Confirmar que **não** alcança o tenant B.
5. Ver (ou apontar) trilha de sessão / audit.
6. Entender o que **não** está no escopo desta homologação.

**Não** é requisito desta homologação: UnifiedUI, Oracle, NetBird, HA, orquestração full de pessoas, peer em N clientes.

---

## 2. Escopo

### 2.1 Inclui (MVP homologação)

| Área | Entrega |
|------|---------|
| Identidade | Login SSO console + Warpgate; offboarding IdP demonstrável |
| Bastion | SSH + Postgres via Warpgate (Linux/macOS; Windows se houver host) |
| Browser (opcional no MVP) | Guac com portão SSO + sessão lab/cliente documentada |
| Control plane | Sites SoT, apply gateways, sync Axis (site + `tenant_*` + role WG), `/platform` |
| Rede | **≥ 1** site com peer/VPN/connector **real** (não só lab overlay) |
| Segurança lab→produto | Sem root OpenBao no fluxo diário; backup PG documentado |
| Evidência | Roteiro UAT + checklist assinado + smoke-evidence da rodada |

### 2.2 Fora de escopo (estacionamento — §7)

- UnifiedUI / catálogo “minhas conexões”
- Guacamole OIDC nativo 1.7 (enquanto portão oauth2-proxy + reteste bastar)
- Oracle credential proxy
- NetBird / malha multi-site / segmentação avançada
- OpenBao HA + auto-unseal KMS
- Provision/revoke de **pessoas** end-to-end via Axis
- Acesso agêntico / OpenSRE / HITL
- SIEM remoto (waiver explícito na homologação)

---

## 3. Como usar este plano

1. Trabalhar **uma fase por vez** (F0 → F1 → … → F5).
2. Marcar tarefas `- [x]` só com evidência (link, path, print, log).
3. Atualizar a tabela **Status da fase** no topo de cada fase.
4. Ao fechar F5, preencher §6 (gate de homologação) e assinar.
5. Itens novos: se forem MVP, viram tarefa na fase certa; se forem pós-MVP, vão para §7.

**Legenda de status de fase**

| Status | Significado |
|--------|-------------|
| `todo` | Não iniciado |
| `doing` | Em execução |
| `blocked` | Dependência externa (cliente, host, aprovação) |
| `done` | Todas as tarefas obrigatórias `[x]` |

---

## 4. Fases e tarefas

### F0 — Alinhamento e recorte

| Campo | Valor |
|-------|--------|
| Status | `todo` |
| Esforço típico | 0,5–1 dia |
| Bloqueia | Tudo abaixo se cliente/dono não definidos |

#### Tarefas

- [ ] **F0.1** Nomear **dono do plano** e **revisor de homologação** (assinam §6).
- [ ] **F0.2** Escolher **cliente piloto #1** (stack de VPN, contato, janela de peer).
- [ ] **F0.3** Congelar escopo MVP: copiar §2 para o e-mail/kickoff de UAT (o que entra / o que não entra).
- [ ] **F0.4** Decidir protocolos obrigatórios no UAT: `SSH` · `Postgres` · `Guac browser` (sim/não) · `Windows` (sim/não).
- [ ] **F0.5** Criar issue/board (GitHub Projects ou equivalente) com as tasks F1–F5 (opcional, 1 card por ID).
- [ ] **F0.6** Atualizar este documento: dono, cliente piloto, data-alvo de UAT: `____/____/______`.

#### Critério de saída F0

Dono + cliente piloto + protocolos UAT definidos por escrito neste arquivo.

---

### F1 — Fechar lab e waivers (confiança no staging)

| Campo | Valor |
|-------|--------|
| Status | `todo` |
| Esforço típico | 1–2 dias |
| Depende de | F0 (parcialmente; pode rodar em paralelo a F0.2 se lab for genérico) |
| Referência | [`runbooks/ACEITE-PILOTO-LAB.md`](./runbooks/ACEITE-PILOTO-LAB.md) |

#### Tarefas

- [ ] **F1.1** Login **OIDC** no console no browser → dashboard (print ou sessão gravada).  
  _Waiver atual: 1.1_
- [ ] **F1.2** Reteste **offboarding** interativo: disable user no Kanidm → próximo SSO falha (console e/ou WG).  
  _Waiver: 1.5_
- [ ] **F1.3** Guacamole: login via portão SSO + **sessão SSH browser** lab (ou cliente) OK.  
  _Waiver: 2.5_
- [ ] **F1.4** Confirmar **gravação** de sessão (path WG e/ou Guac) e anotar path na evidência.  
  _Waiver: 2.6_
- [ ] **F1.5** Activity log: mutação admin (sync Axis ou upsert site) aparece na UI de audit.  
  _Waiver: 5.4_
- [ ] **F1.6** Higiene OpenBao: fluxo admin com `OPENBAO_APP_TOKEN`; root **não** necessário no dia a dia; documentar residual se ainda no env lab.  
  _Waiver: 5.2_
- [ ] **F1.7** Revalidar smoke automático:
  ```bash
  WG_HOST=192.168.1.180 bash deploy/validation/smoke-operator-access.sh
  bash deploy/openbao/smoke-kanidm-jwt.sh
  # opcional isolamento:
  # bash deploy/validation/tenant-isolation-e2e.sh
  ```
- [ ] **F1.8** Atualizar evidência: copiar template → `runbooks/sites/smoke-evidence-YYYY-MM-DD-homolog-prep.md` (ou estender a de 2026-07-11).
- [ ] **F1.9** Revisor assina aceite lab (PASS limpo **ou** PASS com waiver **escrito** + prazo).

#### Critério de saída F1

Aceite lab assinado; waivers restantes só com prazo e aprovador.

---

### F2 — Roteiro e ambiente de UAT (produto “ensaiável”)

| Campo | Valor |
|-------|--------|
| Status | `todo` |
| Esforço típico | 1–2 dias |
| Depende de | F1 recomendado; F0 obrigatório |

#### Tarefas

- [x] **F2.1** Escrever runbook **`runbooks/HOMOLOGACAO-UAT.md`** com:
  - personas (Admin, Operador tenant A, Operador tenant B, Viewer);
  - passos numerados + resultado esperado;
  - tempo-alvo ≤ 30 min;
  - lista “fora de escopo” (link §2.2).  
  _Feito 2026-07-11 — rascunho v0.1; contas UAT e alvo real ainda F2.2 / F3._
- [ ] **F2.2** Provisionar **contas Kanidm de UAT** (não reutilizar só `testuser` de lab se possível):
  - `uat-admin`, `uat-op-a`, `uat-op-b`, `uat-viewer` (nomes livres, documentar).
- [ ] **F2.3** Matriz RBAC na evidência: o que cada persona **vê / não vê** em `/sites` e targets WG.
- [ ] **F2.4** Demo browser: user **sem** super-admin e **sem** `tenant_*` amplo → deny-by-default (sites filtrados).
- [ ] **F2.5** Checklist de endpoints estável: conferir [`runbooks/endpoints-staging.md`](./runbooks/endpoints-staging.md) (id, console, wg, guac).
- [ ] **F2.6** Pacote de snippets para o revisor (SSH + DBeaver/psql) apontando para o **alvo do piloto** (não só lab genérico).
- [ ] **F2.7** Dry-run interno do UAT (executor ≠ revisor) e anotar fricções no `HOMOLOGACAO-UAT.md`.

#### Critério de saída F2

Qualquer revisor consegue seguir o runbook sem “perguntar no chat”.

---

### F3 — Cliente real ponta a ponta (caminho de ouro)

| Campo | Valor |
|-------|--------|
| Status | `todo` |
| Esforço típico | 1–3 semanas (calendário; depende do cliente) |
| Depende de | F0.2, F2 (runbook pode ser atualizado com hosts reais) |
| Risco principal | Janela de rede / peer no cliente |

#### Tarefas

- [ ] **F3.1** Preencher ficha do site piloto (YAML + admin `/sites`):
  - stack VPN (`wireguard` | `openvpn` | `openfortivpn` | …);
  - hosts alvos (SSH/PG);
  - `inventariado=true`; stack ≠ `a_confirmar`.
  - Refs: [`runbooks/sites/INVENTARIO.md`](./runbooks/sites/INVENTARIO.md), [`runbooks/onboarding-cliente-site.md`](./runbooks/onboarding-cliente-site.md).
- [ ] **F3.2** Onboard **peer/connector real** no cliente (checklist `deploy/connector/onboarding-cliente-peer.md`).
- [ ] **F3.3** Validar connector 1/1 e reachability bastion → rede do site (ping/SSH interno conforme stack).
- [ ] **F3.4** Criar/apply **targets Warpgate** do site (console apply ou script) com secrets via `TARGET_SECRET_*` / fluxo seguro (sem senha no inventário).
- [ ] **F3.5** **E2E operador → alvo real**:
  - SSH via WG com user do tenant correto;
  - (se no escopo) Postgres via WG `sslmode=require`.
- [ ] **F3.6** Isolamento: operador do tenant B **não** conecta nos targets do piloto A.
- [ ] **F3.7** Gravação da sessão E2E real anexada (path + sessão id se houver).
- [ ] **F3.8** Atualizar inventário Axis/SoT: slug do piloto alinhado ao Axis; sync orquestra OK.
- [ ] **F3.9** Registrar evidência `smoke-evidence-YYYY-MM-DD-cliente-piloto.md` (comando, hostname do alvo, marker).

#### Critério de saída F3

Critério de ouro: bastion-first até host **real** do cliente, com isolamento e evidência.

---

### F4 — Higiene e operação “de produto”

| Campo | Valor |
|-------|--------|
| Status | `todo` |
| Esforço típico | 2–4 dias |
| Depende de | F1; paralelo a F3 quando possível |

#### Tarefas

- [ ] **F4.1** Documentar e testar **backup** dos PG usados (Warpgate, Guacamole, `archguard_console`) — procedimento + último teste de dump.
- [ ] **F4.2** Documentar **restore dry-run** (ou restore em lab) — data e executor.
- [ ] **F4.3** Runbook de **boot / unseal** OpenBao (timer + falha de task) — link em `/platform` ou runbooks.
- [ ] **F4.4** Inventariar secrets no serviço console: sem `LAB_SSH_PASSWORD`; passwords de alvo só `TARGET_SECRET_*` ou vault.
- [ ] **F4.5** Política lab: `ARCHGATE_LAB=1` e tokens root — o que some antes de “homologado” vs waiver explícito.
- [ ] **F4.6** Conferir TLS/DNS: id, console, wg, guac sem certificado inválido no browser do revisor.
- [ ] **F4.7** (Opcional pré-prod) mTLS ou rede restrita Axis — se não fizer, registrar waiver de homolog **interna**.
- [ ] **F4.8** Lista de contatos on-call lab durante a janela de UAT.

#### Critério de saída F4

Revisor não depende de “alguém no SSH root” para o happy path; disaster básico está escrito.

---

### F5 — Gate de homologação (execução UAT + decisão)

| Campo | Valor |
|-------|--------|
| Status | `todo` |
| Esforço típico | 0,5–1 dia de execução + bugs |
| Depende de | F1–F4 (F3 obrigatório) |

#### Tarefas

- [ ] **F5.1** Congelar build/imagem do console e stacks (anotar digests/tags em evidência).
- [ ] **F5.2** Executar `HOMOLOGACAO-UAT.md` com o **revisor** (não só o executor).
- [ ] **F5.3** Abrir bugs P0/P1 encontrados; zerar P0 antes da assinatura.
- [ ] **F5.4** P1 com plano datado se aceitos com waiver de homologação.
- [ ] **F5.5** Preencher §6 deste documento (resultado + assinaturas).
- [ ] **F5.6** Comunicar decisão: **APTO** / **APTO com ressalvas** / **NÃO APTO** + próxima data.
- [ ] **F5.7** Atualizar [`MATRIZ_FUNCIONALIDADES.md`](./MATRIZ_FUNCIONALIDADES.md) se status de capabilities mudar.

#### Critério de saída F5

§6 assinado = “produto liberado para homologação formal / UAT de stakeholders”.

---

## 5. Roadmap visual (ordem)

```text
F0 Alinhamento ──► F1 Lab limpo ──► F2 Roteiro UAT
                         │                │
                         └───────┬────────┘
                                 ▼
                    F3 Cliente real E2E ◄── crítico de calendário
                                 │
                    F4 Higiene/ops (// F3)
                                 │
                                 ▼
                         F5 Gate UAT + assinatura
                                 │
                                 ▼
                    §7 Backlog pós-homologação
```

| Fase | Pode paralelizar com |
|------|----------------------|
| F0 | — |
| F1 | F0.5–F0.6 |
| F2 | F1 (após F1.1 mínimo) |
| F3 | F2, F4 |
| F4 | F2, F3 |
| F5 | Nada (gate final) |

---

## 6. Gate — decisão de homologação MVP

Preencher só na execução de F5.

| Campo | Valor |
|-------|--------|
| Data UAT | |
| Ambiente | staging `192.168.1.180` / `*.archgate.com.br` |
| Cliente piloto | |
| Build / tags | |
| Resultado | ☐ **APTO** · ☐ **APTO com ressalvas** · ☐ **NÃO APTO** |
| Ressalvas / waivers | |
| Evidências (links) | |
| Executor | |
| Revisor | |
| Assinatura revisor | |
| Data | |

### Definition of Done (checklist final)

- [ ] Aceite lab assinado (F1.9)
- [ ] Runbook UAT executado por revisor (F5.2)
- [ ] ≥1 E2E bastion → **host real** do cliente (F3.5)
- [ ] Isolamento tenant demonstrado (F3.6)
- [ ] Offboarding demonstrado (F1.2)
- [ ] Admin: sites + apply + `/platform` OK no UAT
- [ ] P0 zerados; P1 com plano ou waiver
- [ ] Fora de escopo comunicado (§2.2)
- [ ] Este §6 preenchido e assinado

---

## 7. Estacionamento — pós-homologação (não bloqueia MVP)

Usar como backlog **depois** do gate. Não misturar com F0–F5.

| ID | Item | Pacote OpenSpec | Prioridade sugerida |
|----|------|-----------------|---------------------|
| P-01 | UnifiedUI + catálogo “minhas conexões” | `add-unified-ui-and-orchestration` | P2 |
| P-02 | Guac OIDC nativo Code+PKCE **ou** só UnifiedUI | identity / ADR-007 | P2 |
| P-03 | Orquestração Axis: provision/grant/revoke **pessoas** | unified-ui / ADR-004 | P2 |
| P-04 | Offboarding multi-componente (WG+Guac+Bao) one-shot | orchestration | P2 |
| P-05 | Oracle proxy + plugin OpenBao | `add-oracle-credential-proxy` | P3 |
| P-06 | NetBird + segmentação multi-site | `add-network-mesh` | P3 |
| P-07 | Warpgate SSH cert nativo OpenBao (ou broker de key) | ephemeral | P3 |
| P-08 | OpenBao HA + auto-unseal | `add-agentic-access` / prod | P4 |
| P-09 | Smoke Windows nativo + RDP real | operator-client / mesh | P2 se persona Windows |
| P-10 | SIEM / export audit remoto | ops | P4 |
| P-11 | Acesso agêntico + HITL + kill-switch | `add-agentic-access` | P5 |
| P-12 | Terraform provider Warpgate SoT | ops | P4 |

---

## 8. Rastreio rápido (quadro)

Atualizar a cada sync.

| ID | Fase | Tarefa (resumo) | Status | Dono | Evidência / nota |
|----|------|-----------------|--------|------|------------------|
| F0.1 | F0 | Dono + revisor | todo | | |
| F0.2 | F0 | Cliente piloto #1 | todo | | |
| F0.3 | F0 | Congelar escopo | todo | | |
| F0.4 | F0 | Protocolos UAT | todo | | |
| F1.1 | F1 | OIDC browser | todo | | waiver 1.1 |
| F1.2 | F1 | Offboarding interativo | todo | | waiver 1.5 |
| F1.3 | F1 | Guac sessão | todo | | waiver 2.5 |
| F1.4 | F1 | Recording | todo | | waiver 2.6 |
| F1.5 | F1 | Activity log UI | todo | | waiver 5.4 |
| F1.6 | F1 | OpenBao APP_TOKEN | todo | | waiver 5.2 |
| F1.9 | F1 | Assinatura lab | todo | | |
| F2.1 | F2 | Escrever HOMOLOGACAO-UAT.md | done | | runbooks/HOMOLOGACAO-UAT.md |
| F2.2 | F2 | Contas UAT | todo | | |
| F2.7 | F2 | Dry-run UAT | todo | | |
| F3.1 | F3 | Ficha site real | todo | | |
| F3.2 | F3 | Peer real | todo | | |
| F3.5 | F3 | E2E alvo real | todo | | **crítico** |
| F3.6 | F3 | Isolamento | todo | | |
| F4.1 | F4 | Backup PG | todo | | |
| F4.3 | F4 | Runbook unseal | todo | | |
| F5.2 | F5 | UAT com revisor | todo | | |
| F5.5 | F5 | Assinar §6 | todo | | |

*(Linhas detalhadas das fases: usar checkboxes nas §§ F0–F5; esta tabela é o radar executivo.)*

---

## 9. Referências

| Doc | Uso |
|-----|-----|
| [`runbooks/HOMOLOGACAO-UAT.md`](./runbooks/HOMOLOGACAO-UAT.md) | Roteiro UAT do revisor (F2.1) |
| [`runbooks/ACEITE-PILOTO-LAB.md`](./runbooks/ACEITE-PILOTO-LAB.md) | Aceite lab (não é homologação de produto) |
| [`runbooks/sites/smoke-evidence-*.md`](./runbooks/sites/) | Evidências datadas |
| [`MATRIZ_FUNCIONALIDADES.md`](./MATRIZ_FUNCIONALIDADES.md) | Feito × falta por capability |
| [`runbooks/cliente-operador-multi-os.md`](./runbooks/cliente-operador-multi-os.md) | Padrão operador ADR-008 |
| [`runbooks/onboarding-cliente-site.md`](./runbooks/onboarding-cliente-site.md) | Onboarding site |
| [`runbooks/endpoints-staging.md`](./runbooks/endpoints-staging.md) | URLs lab |
| [`../deploy/README.md`](../deploy/README.md) | Deploy Swarm |
| [`../openspec/changes/README.md`](../openspec/changes/README.md) | Fases de produto longas |
| [`../README.md`](../README.md) | Visão do repositório |

---

## 10. Changelog do plano

| Data | Mudança |
|------|---------|
| 2026-07-11 | Criação do plano F0–F5 + estacionamento pós-MVP |
| 2026-07-11 | F2.1: rascunho `runbooks/HOMOLOGACAO-UAT.md` |
