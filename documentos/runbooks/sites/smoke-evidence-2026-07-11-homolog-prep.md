# Smoke evidence — 2026-07-11 (Homolog prep / execução plano F0–F1)

| Campo | Valor |
|-------|--------|
| Executor | Grok Build (automatizado + host runtime) |
| Revisor | Edson Martins (_assinatura humana pendente em itens browser_) |
| Ambiente | `192.168.1.180` (staging) |
| Plano | [`../../PLAN-HOMOLOGACAO-MVP.md`](../../PLAN-HOMOLOGACAO-MVP.md) |
| Cliente piloto #1 | **Rio Quality** |
| Dono / revisor UAT | **Edson Martins** |
| Protocolos UAT | SSH ✅ · Postgres ✅ · Guac browser (opcional reteste) · Windows ❌ MVP |

---

## F0 — Alinhamento

| Item | Resultado |
|------|-----------|
| F0.1 Dono + revisor | ✅ Edson Martins (dono e revisor) |
| F0.2 Cliente piloto | ✅ Rio Quality |
| F0.3 Escopo | ✅ §2 do plano (MVP; UnifiedUI/Oracle/HA fora) |
| F0.4 Protocolos | ✅ SSH+PG obrigatórios; Guac desejável; Windows fora |
| F0.5 Board issues | ⬜ opcional |
| F0.6 Data-alvo UAT | ⬜ _definir com Edson_ |

---

## 0. Pré-condições (revalidadas)

| Item | Resultado | Evidência |
|------|-----------|-----------|
| Core services 1/1 | ✅ | traefik, kanidmd, console, warpgate, guacamole, guacd, oauth2-proxy, openbao, axis-spring, lab_ssh, piloto_* |
| OpenBao unsealed | ✅ | `Sealed false`, v2.2.0 |
| Timer unseal | ✅ | `archgate-openbao-unseal.timer` ativo (~2 min) |
| Broker DB timer | ✅ | `archgate-broker-db.timer` |
| Axis Spring UP | ✅ | `{"status":"UP"}` :9031 |
| HTTPS (no host) | ✅ | console **307**, id **303**, wg **307**, guac **302** |

---

## F1 — Waivers / smokes

| Item | Resultado | Notas |
|------|-----------|-------|
| F1.1 Console OIDC browser | ⚠️ | Técnico: `console` → 307 `/dashboard`; OIDC discovery client `archguard-console` **200** (`-k`). **Login interativo humano pendente** |
| F1.2 Offboarding interativo | ⚠️ | Não reexecutado nesta rodada (histórico `offboarding-e2e`); reteste humano |
| F1.3 Guac sessão browser | ⚠️ | Portão SSO **PASS** (ver abaixo); sessão gráfica = reteste humano |
| F1.4 Gravação WG | ✅ | Path `/var/lib/archgate/warpgate/recordings/` — **15+** sessões históricas; arquivos presentes |
| F1.4 Gravação Guac | ⚠️ | Dir `/var/lib/archgate/guacamole/recordings` **vazio** nesta checagem |
| F1.5 Activity log | ⚠️→parcial | SQLite `/app/data/archguard.sqlite` estava **0 bytes** (tabela ausente). Schema recriado + linha seed `uat.prep.init_activity_log`. **UI browser e mutação real pendentes** |
| F1.6 OpenBao APP_TOKEN | ⚠️ | `OPENBAO_APP_TOKEN` **presente**; ainda há `OPENBAO_ROOT_TOKEN` + `OPENBAO_UNSEAL_KEY` + `ARCHGATE_LAB` no serviço (lab residual) |
| F1.7 Smoke operador | ✅ | SSH + PG **PASS** |
| F1.7 JWT OpenBao | ✅ | **KANIDM → OPENBAO JWT AUTH PASSED** |
| F1.7 Isolamento tenant | ✅ | `testuser:rio-lab-ssh` → hostname `45baba7d8be4`; `testuser:marra-lab-ssh` → **Permission denied** |
| F1.7 WG admin API (console) | ✅ | login 201, targets 200, roles 200 |
| F1.8 Este arquivo | ✅ | |
| F1.9 Assinatura lab | ⬜ | Revisor humano |

### Smoke operador (trecho)

```
SSH OK marker=ADR008_SMOKE_1783790115_2977344
hostname=45baba7d8be4 user=labuser
Postgres proxy OK (v-token-ar-lab-read-…:1)
Guacamole preflight: guac_http=302; login local guacadmin FAIL (esperado com oauth2-proxy)
```

### Guacamole SSO portão

```
unauthenticated → 302 → id.archgate.com.br/ui/oauth2?...client_id=guacamole...code_challenge...
oauth2-proxy 1/1; OIDC Code/PKCE + preferred_username + pass-user-headers OK
```

### Isolamento manual

```
TARGET=rio-lab-ssh  → 45baba7d8be4
TARGET=marra-lab-ssh → Permission denied (publickey,keyboard-interactive)
```

### Sites SoT

| slug | stack | inventariado |
|------|-------|--------------|
| **rio_quality** | **lab_overlay** | **true** |
| demais (aj_rorato, marra via Axis nome, …) | a_confirmar | false |

---

## F4 — Higiene (parcial, paralelo)

| Item | Resultado | Notas |
|------|-----------|-------|
| DBs PG identificados | ✅ | `warpgate` ~10 MB · `guacamole` ~9 MB · `archguard_console` ~8 MB em `.110:5434` |
| Backup procedure documentado | ⬜ | próximo: runbook dump+restore |
| Sem LAB_SSH no console | ✅ | env sem `LAB_SSH_PASSWORD` |
| Root OpenBao no env | ⚠️ | residual lab — waiver 5.2 |

---

## F3 — Cliente real

| Item | Status |
|------|--------|
| Peer VPN **real** Rio Quality | ⬜ **bloqueado** em janela/cliente — site ainda `lab_overlay` |
| E2E bastion → host real | ⬜ depende F3.2 |

---

## Bloqueios / próximos passos

1. **Humano (Edson):** login OIDC console + Guac sessão + assinar F1.9 / data-alvo UAT (F0.6).  
2. **F2.2:** criar contas `uat-*` no Kanidm (ou confirmar uso de `testuser` no dry-run).  
3. **F3:** contactar Rio Quality para peer real; até lá UAT dry-run usa lab targets.  
4. **F4.1:** script/runbook `pg_dump` dos 3 DBs.  
5. **F1.5:** após mutação real no console (sync/upsert site), confirmar linha nova em activity_log + UI.

---

## Decisão parcial (execução automatizada)

| Campo | Valor |
|-------|--------|
| F0 | **done** (exceto F0.5 opcional e F0.6 data) |
| F1 automatizável | **PASS com waiver** (browser OIDC/Guac/offboarding/UI audit) |
| Pronto para UAT formal (F5)? | **Não** — falta F3 cliente real + assinaturas browser |
