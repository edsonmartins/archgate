# Plano — ArchGate pronto para homologação MVP

| Campo | Valor |
|-------|--------|
| Status do plano | **Ativo** |
| Objetivo | Produto **homologável** (UAT interno / cliente piloto), sem confundir com lab nem com produção multi-cliente |
| Plano 100% produto | [`PLAN-PRODUTO-100.md`](./PLAN-PRODUTO-100.md) (ondas W0–W5 — o que falta além deste MVP) |
| Baseline lab | Aceite piloto **PASS com waiver** (2026-07-11) — [`runbooks/ACEITE-PILOTO-LAB.md`](./runbooks/ACEITE-PILOTO-LAB.md) |
| Evidência lab | [`runbooks/sites/smoke-evidence-2026-07-11-aceite-piloto.md`](./runbooks/sites/smoke-evidence-2026-07-11-aceite-piloto.md) |
| Matriz de features | [`MATRIZ_FUNCIONALIDADES.md`](./MATRIZ_FUNCIONALIDADES.md) |
| Data de criação | 2026-07-11 |
| Última atualização | **2026-07-29** — auditoria codebase × spec (§11); F3 reavaliado com evidência do `archgate-devops` |
| Dono do plano | **Edson Martins** |
| Cliente piloto #1 | **Rio Quality** |
| Revisor UAT | **Edson Martins** |
| Protocolos UAT | SSH + Postgres **obrigatórios**; Guac browser **desejável**; Windows **fora do MVP** |
| Data-alvo UAT | **2026-07-24** (H1 ensaiável; peer real = H2 / waiver se bloqueado) |
| Staging atual | **Hostinger VPS** `217.196.60.108` · `*.archgate.com.br` (CF) · stack Compose colocada c/ Linktor |
| Evidência execução | [`runbooks/sites/smoke-evidence-2026-07-11-homolog-prep.md`](./runbooks/sites/smoke-evidence-2026-07-11-homolog-prep.md) · H1 Hostinger (este ciclo) |

---

## 0. Staging Hostinger + sprints H1–H3 (2026-07-17)

| Sprint | Objetivo | Status |
|--------|----------|--------|
| **H1** | Staging ensaiável neste VPS (UAT personas, targets lab, suite, higiene OpenBao, browser/TLS) | **`done` 2026-07-17** |
| **H2** | Peer real Rio Quality + E2E bastion (F3) | `blocked` calendário |
| **H3** | Gate F5 + assinatura §6.2 | `todo` (após H1; H2 ou waiver peer) |

### H1 checklist

| ID | Entrega | Status | Evidência |
|----|---------|--------|-----------|
| H1.1 | Contas UAT archguard+WG | ✅ | `/root/archgate/uat-credentials.env`; REST auth 4 personas OK; groups bound |
| H1.2 | Targets lab WG + roles tenant | ✅ | SSH/PG E2E lab PASS 2026-07-17; isolamento op-a↛marra; ver `LAB-BASTION-TARGETS.md` |
| H1.3 | Smokes no Hostinger | ✅ | archguard `/status=true`; WG admin login 201; console healthy; inventory roles/targets |
| H1.4 | OpenBao APP_TOKEN | ✅ | policy `archgate-console` + token em `bootstrap.env` + console env |
| H1.5 | TLS endpoints públicos | ✅ | console 307 · id 303 · wg 307 · guac 200 · secrets 307 |
| H1.6 | Viewer deny-by-default | ⏳ revisor | personas OK; UI deny = revisor; **WG:** `uat-op-a` só vê `rio-lab-*` (não marra) ✅ |
| H1.7 | Data-alvo UAT + on-call | ✅ | **2026-07-24** · Edson Martins |
| H1.8 | archguard health | ✅ | Recreate compose: HC `archguardd version` → **healthy**; `/status=true` |

**Evidência H1:** `/root/archgate/H1-HOSTINGER-2026-07-17.md`  
**Freeze H3 prep:** `/root/archgate/H3-FREEZE-2026-07-17.md`  

### H3 prep (sem peer real)

| Item | Status |
|------|--------|
| Freeze digests/imagens | ✅ `H3-FREEZE-2026-07-17.md` |
| Isolamento role matrix WG | ✅ op-a → só targets Rio |
| UAT formal revisor browser | ⏳ Edson até **2026-07-24** |
| Peer real / waiver §6.2 | ⏳ H2 ou assinatura c/ ressalva |

**Admin unificado:** console = única UI diária; stock WG/Guac/OpenBao/archguard = break-glass (`archgate-devops/docs/ADMIN-UNIFICADO.md`).

### W1 Ops Hostinger (paralelo a H3)

| Item | Status | Nota |
|------|--------|------|
| PG backup timer 03:15 | ✅ | `/var/backups/archgate-pg` |
| Recordings + sqlite timer 03:45 | ✅ | `/var/backups/archgate-recordings` |
| Health monitor 15 min | ✅ | fail=0 |
| Restore dry-run | ✅ | temp DB drop |
| Doc | ✅ | `archgate-devops/docs/W1-OPS-HOSTINGER.md` |

---

## 1. Norte (o que “pronto para homologar” significa)

Um revisor (humano) consegue, em **≤ 30 minutos** com o runbook de UAT:

1. Entrar no console via **OIDC archguard**.
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
| Status | `done` (F0.5 opcional aberto; F0.6 data-alvo aberta) |
| Esforço típico | 0,5–1 dia |
| Bloqueia | Tudo abaixo se cliente/dono não definidos |

#### Tarefas

- [x] **F0.1** Nomear **dono do plano** e **revisor de homologação** (assinam §6).  
  _2026-07-11: Edson Martins (dono e revisor)._
- [x] **F0.2** Escolher **cliente piloto #1** (stack de VPN, contato, janela de peer).  
  _2026-07-11: **Rio Quality**. Stack atual no SoT: `lab_overlay` (peer real = F3)._
- [x] **F0.3** Congelar escopo MVP: copiar §2 para o e-mail/kickoff de UAT (o que entra / o que não entra).  
  _Escopo = §2 deste plano._
- [x] **F0.4** Decidir protocolos obrigatórios no UAT: `SSH` · `Postgres` · `Guac browser` (sim/não) · `Windows` (sim/não).  
  _SSH+PG obrigatórios; Guac desejável; Windows fora do MVP._
- [ ] **F0.5** Criar issue/board (GitHub Projects ou equivalente) com as tasks F1–F5 (opcional, 1 card por ID).
- [x] **F0.6** Atualizar este documento: dono, cliente piloto, data-alvo de UAT.  
  _2026-07-17: data-alvo **2026-07-24** (H1 Hostinger); peer real = H2._

#### Critério de saída F0

Dono + cliente piloto + protocolos UAT definidos por escrito neste arquivo. ✅

---

### F1 — Fechar lab e waivers (confiança no staging)

| Campo | Valor |
|-------|--------|
| Status | `doing` |
| Esforço típico | 1–2 dias |
| Depende de | F0 (parcialmente; pode rodar em paralelo a F0.2 se lab for genérico) |
| Referência | [`runbooks/ACEITE-PILOTO-LAB.md`](./runbooks/ACEITE-PILOTO-LAB.md) · evidência homolog-prep |

#### Tarefas

- [x] **F1.1** Login no console → dashboard (sessão).  
  _2026-07-17: `w0-console-session.sh` — cookie + dashboard 200 (uat-*/testadmin). OIDC browser real 1× opcional para revisor._
- [x] **F1.2** Reteste **offboarding** interativo: disable user no archguard → próximo SSO falha (console e/ou WG).  
  _2026-07-17: `offboarding-e2e.sh` **PASSED** (account expired). Browser opcional._
- [x] **F1.3** Guacamole: portão SSO + sessão API + ACL.  
  _2026-07-17: `guacamole-sso-proxy-e2e` + `w0-guac-session` PASS (uat-op-a → rio-lab-ssh-browser). Visual browser opcional._
- [x] **F1.4** Confirmar **gravação** de sessão (path WG e/ou Guac) e anotar path na evidência.  
  _WG: `/var/lib/archgate/warpgate/recordings/` com sessões. Guac dir vazio → reteste com sessão real._
- [x] **F1.5** Activity log / audit acessível.  
  _`/audit` 200 com sessão; activity_log rows≥2. Mutação visual na UI = opcional revisor._
- [x] **F1.6** Higiene OpenBao: fluxo admin com `OPENBAO_APP_TOKEN`; root **não** necessário no dia a dia; documentar residual se ainda no env lab.  
  _APP_TOKEN presente; ROOT residual com `ARCHGATE_LAB` — waiver escrito no openbao-unseal-lab + evidência._
- [x] **F1.7** Revalidar smoke automático:
  ```bash
  WG_HOST=192.168.1.180 bash deploy/validation/smoke-operator-access.sh
  bash deploy/openbao/smoke-archguard-jwt.sh
  # isolamento manual: rio OK / marra denied
  ```
  _SSH+PG PASS · JWT PASS · isolamento PASS · WG admin API PASS._
- [x] **F1.8** Atualizar evidência: `runbooks/sites/smoke-evidence-2026-07-11-homolog-prep.md`.
- [x] **F1.9** Aceite lab técnico (§6.1 APTO com ressalvas 2026-07-17).  
  _Assinatura humana formal = §6.2 quando Edson confirmar._

#### Critério de saída F1

Aceite lab assinado; waivers restantes só com prazo e aprovador.

---

### F2 — Roteiro e ambiente de UAT (produto “ensaiável”)

| Campo | Valor |
|-------|--------|
| Status | `doing` |
| Esforço típico | 1–2 dias |
| Depende de | F1 recomendado; F0 obrigatório |

#### Tarefas

- [x] **F2.1** Escrever runbook **`runbooks/HOMOLOGACAO-UAT.md`** com:
  - personas (Admin, Operador tenant A, Operador tenant B, Viewer);
  - passos numerados + resultado esperado;
  - tempo-alvo ≤ 30 min;
  - lista “fora de escopo” (link §2.2).  
  _Feito 2026-07-11 — rascunho v0.1; contas UAT e alvo real ainda F2.2 / F3._
- [x] **F2.2** Provisionar **contas archguard de UAT** (não reutilizar só `testuser` de lab se possível):
  - `uat-admin`, `uat-op-a`, `uat-op-b`, `uat-viewer`  
  _2026-07-11: archguard + Warpgate. Script `deploy/validation/provision-uat-users.sh`. Creds: `/root/archgate/uat-credentials.env`._
- [x] **F2.3** Matriz RBAC na evidência: o que cada persona **vê / não vê** em `/sites` e targets WG.  
  _Ver tabela em `HOMOLOGACAO-UAT.md` §0.3 + smoke `uat-op-a` rio OK / marra deny._
- [ ] **F2.4** Demo browser: user **sem** super-admin e **sem** `tenant_*` amplo → deny-by-default (sites filtrados).  
  _Hostinger H1: `uat-viewer` provisionado (sem tenant). Bastion sem roles WG. Console UI deny = revisor em UAT formal._
- [x] **F2.5** Checklist de endpoints estável: conferir [`runbooks/endpoints-staging.md`](./runbooks/endpoints-staging.md) (id, console, wg, guac).  
  _2026-07-11: URLs OK no host (307/303/307/302)._
- [x] **F2.6** Pacote de snippets para o revisor (SSH + DBeaver/psql) apontando para o **alvo do piloto** (não só lab genérico).  
  _UAT usa `uat-op-a:rio-lab-*` em HOMOLOGACAO-UAT; hosts reais após F3._
- [x] **F2.7** Dry-run interno do UAT (executor ≠ revisor) e anotar fricções no `HOMOLOGACAO-UAT.md`.  
  _2026-07-11 auto: SSH/PG/isolamento 4 personas PASS. Fricções: (1) OIDC/Guac browser humano; (2) cert Traefik DEFAULT no lab para SNI local; (3) F3 peer real._

#### Critério de saída F2

Qualquer revisor consegue seguir o runbook sem “perguntar no chat”.  
_Quase: parte bastion ensaiável; parte browser + assinatura ainda com Edson._

---

### F3 — Cliente real ponta a ponta (caminho de ouro)

| Campo | Valor |
|-------|--------|
| Status | `doing` — conectividade e targets reais **feitos**; falta o E2E do operador e a evidência (ver §11.2) |
| Esforço típico | 1–3 semanas (calendário; depende do cliente) |
| Depende de | F0.2, F2 (runbook pode ser atualizado com hosts reais) |
| Risco principal | Janela de rede / peer no cliente |

#### Tarefas

- [x] **F3.1** Preencher ficha do site piloto (YAML + admin `/sites`).
  _Feito: `scripts/71-import-rio-site-console.sh`; ficha em `archgate-devops/inventory/clients/rio-quality.site.yaml`._
- [x] **F3.2** Onboard **peer/connector real** no cliente.
  _Feito: OpenVPN ativo (`tun0`, rota `10.0.0.0/16`) + unit openfortivpn no VPS._
- [x] **F3.3** Validar connector 1/1 e reachability bastion → rede do site.
  _Probes `10.0.25.18/62`, `10.0.31.102:22` OPEN — `archgate-devops/docs/RESIDUAL-SPRINT1.md`._
- [x] **F3.4** Criar/apply **targets Warpgate** do site.
  _`rio-aws-obs`, `rio-aws-api-a`, `rio-aws-api-b` com pubkey instalada (scripts 72/73). Residual: `authorized_keys` no gestor `192.168.0.214`._
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
| Status | `doing` |
| Esforço típico | 2–4 dias |
| Depende de | F1; paralelo a F3 quando possível |

#### Tarefas

- [x] **F4.1** Documentar e testar **backup** dos PG usados (Warpgate, Guacamole, `archguard_console`) — procedimento + último teste de dump.  
  _Runbook [`runbooks/backup-postgres-lab.md`](./runbooks/backup-postgres-lab.md). Dump 2026-07-11 ` /var/backups/archgate-pg/*-20260711-141705.dump` no runtime._
- [x] **F4.2** Documentar **restore dry-run** (ou restore em lab) — data e executor.  
  _2026-07-11: restore `archguard_console` → DB temp → sites=6 → drop. PASS._
- [x] **F4.3** Runbook de **boot / unseal** OpenBao (timer + falha de task) — link em `/platform` ou runbooks.  
  _[`runbooks/openbao-unseal-lab.md`](./runbooks/openbao-unseal-lab.md); timer enabled, last run OK._
- [x] **F4.4** Inventariar secrets no serviço console: sem `LAB_SSH_PASSWORD`; passwords de alvo só `TARGET_SECRET_*` ou vault.  
  _Sem `LAB_SSH_PASSWORD` no console (2026-07-11)._
- [x] **F4.5** Política lab: `ARCHGATE_LAB=1` e tokens root — o que some antes de “homologado” vs waiver explícito.  
  _Waiver: root/unseal no env lab até hardening prod; documentado no unseal runbook._
- [ ] **F4.6** Conferir TLS/DNS: id, console, wg, guac sem certificado inválido no browser do revisor.  
  _Nota lab: `openssl` via 127.0.0.1 mostra **TRAEFIK DEFAULT CERT** (SNI/LE path público pode diferir). Validar no browser do revisor com DNS público._
- [x] **F4.7** (Opcional pré-prod) mTLS ou rede restrita Axis — se não fizer, registrar waiver de homolog **interna**.  
  _Waiver homolog interna: Axis lab sem mTLS._
- [x] **F4.8** Lista de contatos on-call lab durante a janela de UAT.  
  _2026-07-17: **Edson Martins** (on-call H1/H3 Hostinger)._

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

### 6.1 Decisão automatizada de lab (2026-07-17)

| Campo | Valor |
|-------|--------|
| Data UAT lab | **2026-07-17** |
| Ambiente | staging `192.168.1.180` / `*.archgate.com.br` |
| Cliente piloto | **Rio Quality** (lab_overlay; peer real **pendente**) |
| Build / tags | `archguard-console:local` (redeploy 2026-07-17) |
| Resultado lab | ☑ **APTO com ressalvas** · ☐ APTO limpo · ☐ NÃO APTO |
| Ressalvas / waivers | (1) Peer/VPN **real** Rio ainda não onboardado — E2E é lab targets. (2) OIDC/Guac **visual** browser 1× opcional (API/sessão validados). (3) `ARCHGUARD_E2E_LOGIN=1` lab — desligar pós-UAT formal se desejado. (4) OpenBao root residual em env lab. |
| Evidências | [`sites/smoke-evidence-2026-07-11-homolog-prep.md`](./sites/smoke-evidence-2026-07-11-homolog-prep.md) · `w0-validate` · `w0-console-session` · `w0-guac-session` · `offboarding-e2e` · `w0-all.sh` |
| Executor | Grok Build + host runtime |
| Revisor | Edson Martins |
| Assinatura revisor | _pendente confirmação humana_ |
| Data | 2026-07-17 |

### 6.2 Assinatura humana (F5 formal)

| Campo | Valor |
|-------|--------|
| Confirmo §6.1 | ☐ Sim · ☐ Ajustar ressalvas |
| Data UAT formal | |
| Assinatura revisor | |
| Data | |

### Definition of Done (checklist final)

- [x] Aceite lab técnico documentado (§6.1) — assinatura humana em §6.2
- [x] Runbook UAT coberto por suite auto (`w0-all` / session / guac / bastion) — revisor §6.2
- [ ] ≥1 E2E bastion → **host real** do cliente (F3.5 / W0-B) — **waiver ativo**
- [x] Isolamento tenant demonstrado (lab UAT personas + guac ACL)
- [x] Offboarding demonstrado (F1.2) — e2e auto 2026-07-17
- [x] Admin: sites/platform/gateways/audit shells 200 com sessão UAT
- [x] P0 lab zerados; P1 = peer real + assinatura §6.2
- [x] Fora de escopo comunicado (§2.2)
- [ ] Este §6 assinado em §6.2 pelo revisor

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
| F0.1 | F0 | Dono + revisor | **done** | Edson | |
| F0.2 | F0 | Cliente piloto #1 | **done** | Edson | Rio Quality |
| F0.3 | F0 | Congelar escopo | **done** | | §2 plano |
| F0.4 | F0 | Protocolos UAT | **done** | | SSH+PG; Guac opcional |
| F0.6 | F0 | Data-alvo UAT | todo | Edson | |
| F1.1 | F1 | OIDC browser | doing | Edson | pré-check 307 OK |
| F1.2 | F1 | Offboarding interativo | **done** | | e2e 2026-07-17 |
| F1.3 | F1 | Guac sessão | doing | | portão SSO PASS |
| F1.4 | F1 | Recording WG | **done** | | path WG OK |
| F1.5 | F1 | Activity log UI | doing | | sqlite reinit |
| F1.6 | F1 | OpenBao APP_TOKEN | doing | | root residual lab |
| F1.7 | F1 | Smokes auto | **done** | | SSH/PG/JWT/isol |
| F1.8 | F1 | Evidência homolog-prep | **done** | | smoke-evidence-…-homolog-prep |
| F1.9 | F1 | Assinatura lab | todo | Edson | |
| F2.1 | F2 | Escrever HOMOLOGACAO-UAT.md | **done** | | |
| F2.2 | F2 | Contas UAT | **done** | | uat-* archguard+WG |
| F2.3 | F2 | Matriz RBAC | **done** | | HOMOLOGACAO-UAT §0.3 |
| F2.5 | F2 | Endpoints | **done** | | |
| F2.7 | F2 | Dry-run UAT auto | **done** | | SSH/PG/isol PASS |
| F3.1–F3.4 | F3 | Peer + targets reais Rio | **done** | Edson | OpenVPN up; 3 targets AWS |
| F3.5–F3.9 | F3 | E2E operador + evidência | todo | Edson | falta rodada UAT |
| F4.1 | F4 | Backup PG | **done** | | dump 20260711-141705 |
| F4.2 | F4 | Restore dry-run | **done** | | sites=6 |
| F4.3 | F4 | Unseal runbook | **done** | | openbao-unseal-lab.md |
| F4.4 | F4 | Sem LAB_SSH console | **done** | | |
| F4.5 | F4 | Waiver root lab | **done** | | |
| F4.6 | F4 | TLS browser | todo | Edson | validar DNS público |
| F4.7 | F4 | Waiver Axis mTLS | **done** | | homolog interna |
| F5.2 | F5 | UAT com revisor | todo | Edson | |
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
| 2026-07-11 | Execução: F0 fechado (Rio Quality + Edson); F1 smokes PASS; evidência homolog-prep; F3 blocked peer real |
| 2026-07-11 | F2.7 dry-run auto (SSH/PG/isolamento uat-*); F4.2 restore PASS; F4.3 unseal runbook |


---

## 11. Auditoria codebase × spec — 2026-07-28/29

Auditoria completa do repositório contra as specs, incluindo os repositórios
irmãos `_archguard/archguard-console` e `archgate-devops`.

### 11.1 Bloqueadores corrigidos

| ID | Achado | Correção |
|----|--------|----------|
| P0-1 | `Bearer lab-<user>` forjável dava sessão com `tenant_rio_quality` no console público | Segredo compartilhado obrigatório, comparação em tempo constante, grupos sem tenant de cliente; deploy default `0` |
| P0-2 | `/test-login` com senha hardcoded + rate limit desligado no staging | Senha só por env; rate limit com flag própria; deploy default `0` |
| P0-3 | API de orquestração pública e anônima (`orch.archgate.com.br`) | Token de serviço fail-closed, HMAC nos webhooks, `traefik.enable=false` |
| P1-1 | `npm run typecheck` do console vermelho (15 erros) → CI vermelha no `main` | Zerado; `npm run check` verde |
| P1-2 | `agent-control` anônimo com `agent_id` autodeclarado; HITL contornável | Credenciais separadas agente/aprovador; identidade da credencial |
| P1-3 | Backup da trilha de auditoria (SQLite WAL) podia sair inconsistente | Hot backup + sidecars WAL + `integrity_check` + dry-run de restore |
| P1-4 | Zero E2E nas telas de control plane e no BFF | `control-plane.spec.ts` + `unified-bff.spec.ts` |
| P1-5 | Nenhuma CI no monorepo | `.github/workflows/ci.yml` (Java, Go, UI, shell) |

### 11.2 Bugs encontrados pelas novas verificações

| Onde | Bug |
|------|-----|
| `deploy/postgres/provision-external.sh` | Heredoc sem `)` — script nunca executaria |
| `deploy/mentors-axis/sync-tenants-cli.sh` | `&&` no topo abortava o script sob `set -e` |
| `archguard-console/src/server/logger.ts` | `pino-pretty` ausente derrubava o dev server no boot (E2E não subia) |
| `archguard-console/src/server/org-accounts.ts` | Backfill sem `name` lançava “name required” |
| `_archguard/.github/workflows/e2e.yml` | archguard sem TLS — o job nunca subia |
| `clients/archgate-connect/.../icons/` | `AppIcon.iconset` com nomes corrompidos; `iconutil` falhava |

### 11.3 O que a auditoria **não** mudou

- Peer/E2E de cliente real (F3.5–F3.9) continua pendente de rodada com revisor.
- `ORCH_MODE` segue `mock`/`dry-run`; adapters live continuam não calibrados.
- Oracle real, NetBird, HA e OpenBao HA seguem fora do MVP (§2.2).
- Trilha de auditoria continua em SQLite de nó único — agora com backup
  verificado; migração para Postgres é decisão de arquitetura em aberto.
