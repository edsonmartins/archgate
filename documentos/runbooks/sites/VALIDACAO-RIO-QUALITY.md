# Validação Rio Quality — por tipo de conexão e acesso

| Campo | Valor |
|-------|--------|
| Cliente | **Rio Quality** |
| Slug / tenant | `rio_quality` · Kanidm `tenant_rio_quality` · WG role `tenant-rio-quality` |
| Staging | Hostinger `217.196.60.108` · `*.archgate.com.br` |
| Inventário | [`archgate-devops/inventory/clients/rio-quality.md`](../../../../archgate-devops/inventory/clients/rio-quality.md) |
| Ficha SoT | [`rio-quality.site.yaml`](../../../../archgate-devops/inventory/clients/rio-quality.site.yaml) |
| Peer runbook | [`RIO-QUALITY-PEER.md`](../../../../archgate-devops/docs/RIO-QUALITY-PEER.md) |
| UAT formal | [`HOMOLOGACAO-UAT.md`](../HOMOLOGACAO-UAT.md) · §6.2 em [`PLAN-HOMOLOGACAO-MVP.md`](../../PLAN-HOMOLOGACAO-MVP.md) |
| First-use | [`PLAN-FIRST-USE-2026-07-24.md`](../../PLAN-FIRST-USE-2026-07-24.md) |
| Evidence template | [`smoke-evidence-TEMPLATE.md`](./smoke-evidence-TEMPLATE.md) |
| **Auto-report (Python)** | [`deploy/validation/rio_quality_report/`](../../../deploy/validation/rio_quality_report/) |
| Data do runbook | 2026-07-25 |

### Relatório automático

```bash
# na raiz do monorepo archgate
python3 -m deploy.validation.rio_quality_report
# deep (SSH/PG com senha Warpgate):
#   UAT_PASS_uat_op_a='…' python3 -m deploy.validation.rio_quality_report --deep
# peers VPS + scripts devops:
#   … --remote-peer --devops-scripts
```

Saída: `documentos/evidence/smoke-evidence-YYYY-MM-DD-rio-quality-auto.{md,json}`

### Princípio

```text
Operador (Mac, SEM VPN do cliente)
  → SSO ArchGate (Kanidm)
  → Connect / SSH / psql / browser embutido
  → Warpgate (wg.archgate.com.br :2222 / :55432)
  → peer no VPS
        ├─ rio-forti (openfortivpn) → LAN 192.168.* (Gestor, Oracle)
        └─ rio-aws   (OpenVPN)      → 10.0.0.0/16 (EC2, PG)
```

**Não** validar com `conecta_rq` / Forti / OpenVPN no notebook no happy path (XOR com peer VPS).

---

## Personas

| Persona | Kanidm / uso | Warpgate |
|---------|--------------|----------|
| `uat-admin` | Admin Manager (sites, grant, platform) | amplo |
| `uat-op-a` | Operador **Rio** | role `tenant-rio-quality` |
| `uat-op-b` | Operador **outro tenant** (isolamento) | `tenant-grupo-marra` |
| `uat-viewer` | Viewer deny UI | sem roles de target |

Credenciais UAT (só runtime VPS): `/root/archgate/uat-credentials.env`  
Mac operador: ArchGate Connect app ou CLI `archgate` (`~/.local/bin/archgate`).

---

## Rodada — cabeçalho de evidência

| Campo | Valor |
|-------|--------|
| Data | YYYY-MM-DD |
| Executor | |
| Revisor | |
| Mac sem VPN cliente? | sim / não |
| Peer `rio-aws` | active / down |
| Peer `rio-forti` | active / down |
| Decisão parcial | PASS / PASS c/ ressalvas / FAIL |
| Evidence file | `smoke-evidence-YYYY-MM-DD-rio-quality.md` |

---

## 0. Pré-condições

### 0.1 Plataforma

```bash
cd archgate-devops
./scripts/67-sprint1-readiness.sh
./scripts/74-smoke-grant-bootstrap.sh
```

| # | Check | ☐ | Resultado / nota |
|---|-------|---|------------------|
| 0.1.1 | `67` PASS (console, kanidm, wg, orch, agent…) | ☐ | |
| 0.1.2 | Bootstrap lab `GET /api/unified/v1/operator/bootstrap` 200 | ☐ | |
| 0.1.3 | Grant `uat-op-a` → role `tenant-rio-quality` (74 ou Manager) | ☐ | |

### 0.2 Peers (conectividade no VPS)

```bash
./scripts/64-onboard-rio-peer.sh --status
./scripts/65-smoke-rio-peer.sh
```

| # | Check | ☐ | Resultado / nota |
|---|-------|---|------------------|
| 0.2.1 | `rio-aws` (OpenVPN) active + rota `10.0.0.0/16` | ☐ | |
| 0.2.2 | Probe `10.0.25.18/62` e `10.0.31.102:22` OPEN (no VPS) | ☐ | |
| 0.2.3 | `rio-forti` active (LAN) | ☐ | |
| 0.2.4 | Probe `192.168.0.214:22` (gestor) — se Forti up | ☐ | |
| 0.2.5 | Mac **sem** Forti/`conecta_rq` no teste | ☐ | |

### 0.3 Identidade operador

```bash
archgate login --lab --user SEU_USER
# ou: archgate login   # SSO
export ARCHGATE_WG_USER=uat-op-a   # se necessário
archgate doctor
archgate ls
```

| # | Check | ☐ | Resultado / nota |
|---|-------|---|------------------|
| 0.3.1 | `doctor` bastion SSH/PG OPEN | ☐ | |
| 0.3.2 | `ls` lista targets Rio (sem IP 10.x/192.x no catálogo) | ☐ | |
| 0.3.3 | `warpgate_user` = `uat-op-a` (ou operador real) | ☐ | |

---

## A — Rede / peer

| ID | Validação | Como | Pass | ☐ | Nota |
|----|-----------|------|------|---|------|
| A1 | OpenVPN AWS up | unit + `tun0` + rota 10/16 | active | ☐ | |
| A2 | Probe EC2 | `nc` 10.0.25.18/62, 10.0.31.102:22 no VPS | OPEN | ☐ | |
| A3 | Forti LAN up | unit `rio-forti` / ppp | active | ☐ | |
| A4 | Probe LAN gestor | `nc` 192.168.0.214:22 no VPS | OPEN | ☐ | |
| A5 | Mac sem VPN cliente | ifaces/rotas locais | só bastion | ☐ | |

---

## B — SSH (Warpgate)

Bastion: `217.196.60.108:2222` ou `wg.archgate.com.br:2222`  
User formato: `OPERADOR:TARGET` · senha = **Warpgate do operador**, não PEM do cliente.

### B1. Lab (sempre)

| ID | Target | Comando / app | Pass | ☐ | Nota |
|----|--------|---------------|------|---|------|
| B1.1 | `rio-lab-ssh` | `ssh -p 2222 'uat-op-a:rio-lab-ssh@217.196.60.108'` | shell + hostname lab | ☐ | |
| B1.2 | idem | Connect → aba SSH embutida | xterm no app | ☐ | |

### B2. AWS real (`connector-rio-aws`)

| Target | Host backend | User backend |
|--------|--------------|--------------|
| `rio-aws-obs` | `10.0.25.18` | `ec2-user` |
| `rio-aws-api-a` | `10.0.25.62` | `ec2-user` |
| `rio-aws-api-b` | `10.0.31.102` | `ec2-user` |

```bash
ssh -p 2222 'uat-op-a:rio-aws-api-b@217.196.60.108'
# ou app:
archgate go rio-aws-api-b --terminal
```

| ID | Check | Pass | ☐ | Nota |
|----|-------|------|---|------|
| B2.1 | Auth WG (senha operador) | aceita | ☐ | |
| B2.2 | Shell no EC2 `rio-aws-api-b` | `hostname` do alvo | ☐ | |
| B2.3 | `rio-aws-api-a` (amostra) | shell OK | ☐ | |
| B2.4 | `rio-aws-obs` (amostra) | shell OK | ☐ | |
| B2.5 | Connect embutido (não Terminal.app) | aba RDM | ☐ | |
| B2.6 | Pubkey WG no backend | hop sem PEM no Mac | ☐ | |

**Falha típica:** peer OpenVPN down → bastion responde, hop interno timeout.

### B3. LAN — Gestor (`connector-rio-forti`)

| Target | Host | User |
|--------|------|------|
| `rio-gestor-linux` | `192.168.0.214:22` | `mentors` |

```bash
ssh -p 2222 'uat-op-a:rio-gestor-linux@217.196.60.108'
```

| ID | Check | Pass | ☐ | Nota |
|----|-------|------|---|------|
| B3.1 | Peer Forti up | probe 214 OPEN | ☐ | |
| B3.2 | `authorized_keys` Warpgate no gestor | shell | ☐ | residual se key pendente |
| B3.3 | Hostname Gestor RQ | confirma alvo | ☐ | |

---

## C — Postgres (Warpgate :55432)

User: `OPERADOR:TARGET` · `sslmode=require` · senha = Warpgate operador.

### C1. Lab

```bash
psql "host=217.196.60.108 port=55432 user=uat-op-a:rio-lab-postgres dbname=archgate_lab sslmode=require" \
  -c 'select 1 as uat_ok;'
```

| ID | Check | ☐ | Nota |
|----|-------|---|------|
| C1.1 | `select 1` lab | ☐ | |
| C1.2 | Connect aba DB embutida | ☐ | |

### C2. AWS real

| Target | Backend |
|--------|---------|
| `rio-aws-pg-a` | `10.0.25.62:5432` |
| `rio-aws-pg-b` | `10.0.31.102:5432` |

```bash
psql "host=217.196.60.108 port=55432 user=uat-op-a:rio-aws-pg-a dbname=<DB> sslmode=require" -c 'select 1'
```

| ID | Check | Pass | ☐ | Nota |
|----|-------|------|---|------|
| C2.1 | Target no catálogo / WG | listado | ☐ | |
| C2.2 | Secret no Warpgate (secret_ref) | connect OK | ☐ | residual se vazio |
| C2.3 | `select 1` | 1 row | ☐ | |
| C2.4 | Sem IP 10.x no Mac | só bastion | ☐ | |
| C2.5 | Connect embutido `psql` | aba DB | ☐ | |

---

## D — Oracle (LAN Forti + Manager)

| Target | Host:porta | Service |
|--------|------------|---------|
| `rio-oracle-prod` | `192.168.0.112:1522` | `WINT` |
| `rio-oracle-tst` | `192.168.0.25:1522` | `WINTTST` |

**Caminho produto:** peer Forti → https://console.archgate.com.br/oracle → lease dinâmico → SQL client.

| ID | Check | Pass | ☐ | Nota |
|----|-------|------|---|------|
| D1 | Reach 1522 no VPS (Forti) | TCP OPEN | ☐ | |
| D2 | UI `/oracle` carrega | 200 / UI OK | ☐ | |
| D3 | `ORACLE_PROXY_MOCK=false` + JDBC | health real | ☐ | scaffold se mock |
| D4 | Emit lease → connect → revoke | E2E | ☐ | fase C / W3 |
| D5 | Connect target oracle → painel embutido | iframe `/oracle` | ☐ | |
| D6 | Sem senha DBA no notebook | só lease TTL | ☐ | |

> Fora do gate MVP homolog se SSH/PG bastion OK (plano §2.2) — marcar **ressalva** se D incompleto.

---

## E — HTTPS / apps web

| Alvo | Via | Validação |
|------|-----|-----------|
| Gestor HTTPS `192.168.0.214:443` | Forti | target HTTP WG / open embutido se catalogado |
| Grafana obs `10.0.25.18` | AWS | SSH jump ou publish — N/A se sem target WG |

| ID | Check | ☐ | Nota |
|----|-------|---|------|
| E1 | HTTPS gestor alcançável via peer (VPS) | ☐ | |
| E2 | Connect/Web embutido se target existir | ☐ | |
| E3 | Sem IP privado no happy path do Mac | ☐ | |

---

## F — Guacamole (browser / RDP-VNC embutido)

| Canal | URL / app |
|-------|-----------|
| Browser | https://guac.archgate.com.br |
| Connect | target `engine=guacamole` ou protocol `rdp`/`vnc` |

| ID | Check | Pass | ☐ | Nota |
|----|-------|------|---|------|
| F1 | Portão SSO (redirect IdP) | login Kanidm | ☐ | |
| F2 | Sessão SSH lab no Guac | shell browser | ☐ | |
| F3 | Connect embutido (iframe/WS) | sem browser externo default | ☐ | |
| F4 | Recording (opcional) | path/audit | ☐ | |
| F5 | RDP Windows real | N/A se sem host | ☐ | inventário Rio sem Windows |

---

## G — Isolamento e RBAC

| ID | Teste | Ação | Pass | ☐ | Nota |
|----|-------|------|------|---|------|
| G1 | Rio ↛ Marra | `ssh -p 2222 'uat-op-a:marra-lab-ssh@217.196.60.108'` | **denied** | ☐ | |
| G2 | Rio OK | `…:rio-aws-api-b@…` (ou lab) | shell | ☐ | |
| G3 | Marra ↛ Rio (opc.) | `uat-op-b` em target Rio | denied | ☐ | |
| G4 | Viewer | console como `uat-viewer` | sem mutação / empty | ☐ | |
| G5 | Catálogo Connect | `archgate ls` | só Rio; sem IPs internos | ☐ | |
| G6 | Grant live WG | Manager ou script 74 | bind role OK | ☐ | |

---

## H — Admin Manager (control plane)

| ID | Ação | Pass | ☐ | Nota |
|----|------|------|---|------|
| H1 | `/sites/rio_quality` | dual connectors + targets | ☐ | |
| H2 | Status connectors Forti/AWS | active / probe | ☐ | |
| H3 | Apply gateways (ou 72/73 documentado) | targets no WG | ☐ | |
| H4 | Provision / grant / revoke pessoa | steps OK; grant WG real | ☐ | |
| H5 | `/platform` | Kanidm/WG/OpenBao legíveis | ☐ | |
| H6 | `/audit` | activity grant/login | ☐ | |
| H7 | `/oracle` | UI sobe | ☐ | |

URLs:

- Wizard: https://console.archgate.com.br/sites/wizard  
- Site: https://console.archgate.com.br/sites/rio_quality  
- Oracle: https://console.archgate.com.br/oracle  
- Identities: https://console.archgate.com.br/identities  
- Audit: https://console.archgate.com.br/audit  

---

## I — ArchGate Connect (cliente notebook)

| ID | Fluxo | Pass | ☐ | Nota |
|----|-------|------|---|------|
| I1 | Login lab | catálogo Rio | ☐ | |
| I2 | Login SSO (`oidc.env`) | `auth=oidc` | ☐ | |
| I3 | SSH embutido `rio-aws-api-b` | aba xterm | ☐ | |
| I4 | DB embutido lab/AWS | aba psql | ☐ | |
| I5 | Preferências terminal (global + por target) | aplica na sessão | ☐ | |
| I6 | Mac sem VPN cliente | doctor OPEN | ☐ | |
| I7 | “Abrir externo” só fallback | não é default | ☐ | |

```bash
archgate login --lab --user SEU_USER
export ARCHGATE_WG_USER=uat-op-a
archgate ls
archgate doctor
archgate go rio-aws-api-b --terminal
archgate go rio-lab-postgres
# App: open dist/ArchGate\ Connect.app
```

---

## Ordem sugerida (~45–60 min)

| Min | Bloco | IDs |
|-----|-------|-----|
| 0–5 | Plataforma + peers | 0.x, A |
| 5–7 | Grant/role | 0.1.3, G6 |
| 7–12 | SSH lab + isolamento | B1, G1–G2 |
| 12–25 | SSH AWS real + Connect | B2, I3 |
| 25–35 | Postgres | C1–C2 |
| 35–40 | Gestor LAN (se Forti) | B3 |
| 40–50 | Admin + viewer | H, G4 |
| 50–55 | Guac / Oracle UI | F, D (ressalva OK) |
| 55–60 | Evidence + §6.2 | abaixo |

---

## Critério de saída

### Piloto operacional (mínimo)

- [ ] Peer `rio-aws` estável  
- [ ] SSH real em ≥1 de `rio-aws-api-*` / `rio-aws-obs` (CLI **ou** Connect embutido)  
- [ ] Isolamento Marra deny (G1)  
- [ ] Mac sem VPN cliente no teste (A5 / I6)  
- [ ] Evidence datada preenchida  

### Homologação formal

- [ ] Runbook [`HOMOLOGACAO-UAT.md`](../HOMOLOGACAO-UAT.md) ponta a ponta  
- [ ] §6.2 assinado em [`PLAN-HOMOLOGACAO-MVP.md`](../../PLAN-HOMOLOGACAO-MVP.md)  
  - APTO · APTO com ressalvas · NÃO APTO  
- [ ] Ressalvas explícitas (LAN gestor key, PG secrets, Oracle mock, RDP N/A, …)  

---

## Break-glass (ops)

```bash
cd archgate-devops
./scripts/67-sprint1-readiness.sh
./scripts/64-onboard-rio-peer.sh --status
./scripts/65-smoke-rio-peer.sh
./scripts/66-install-connector-agent.sh    # agent caído
./scripts/72-apply-rio-ssh-warpgate.sh     # apply SSH SoT WG
./scripts/73-apply-rio-postgres-warpgate.sh
./scripts/74-smoke-grant-bootstrap.sh
```

Allowlist cliente (IP saída VPS): **`217.196.60.108`**.

---

## Registro rápido da rodada

| Bloco | Resultado (PASS/FAIL/N/A) | Ressalva |
|-------|---------------------------|----------|
| A Peer | | |
| B SSH | | |
| C Postgres | | |
| D Oracle | | |
| E HTTPS | | |
| F Guac | | |
| G Isolamento | | |
| H Admin | | |
| I Connect | | |

**Decisão final:** _______________________  
**Assinatura / data:** _______________________  

---

## Histórico

| Data | Nota |
|------|------|
| 2026-07-25 | Runbook criado a partir da auditoria first-use + inventário Rio dual peer |
| 2026-07-24 | Smoke bootstrap/grant PASS; Connect embutido SSH/DB/Guac/Web no monorepo |
