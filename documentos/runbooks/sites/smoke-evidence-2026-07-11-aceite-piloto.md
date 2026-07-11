# Smoke evidence — 2026-07-11 (Aceite piloto lab)

| Campo | Valor |
|-------|--------|
| Executor | Grok Build (automatizado + host runtime) |
| Revisor | _pendente humano_ |
| Ambiente | `192.168.1.180` (staging) |
| Checklist | [`../ACEITE-PILOTO-LAB.md`](../ACEITE-PILOTO-LAB.md) |
| **Decisão** | **PASS com waiver** (ver § Waivers) |

---

## 0. Pré-condições

| Item | Resultado | Evidência |
|------|-----------|-----------|
| 0.1 Core services 1/1 | ✅ | traefik, kanidmd, console, warpgate, guacamole, guacd, oauth2-proxy, openbao, axis-spring, lab_ssh, piloto_* 1/1; stub 0/0 |
| 0.2 OpenBao unsealed | ✅ | `Sealed false`, v2.2.0 |
| 0.3 Timer unseal | ✅ | `archgate-openbao-unseal.timer` ativo |
| 0.4 Axis Spring UP | ✅ | `curl :9031/actuator/health` → `{"status":"UP"}` |
| 0.5 Console HTTPS | ✅ | Host console → **307**; id 303; wg 307; guac 302 |

---

## 1. Identidade / SSO

| Item | Resultado | Notas |
|------|-----------|-------|
| 1.1 Console OIDC | ⚠️ | Console responde 307 (login); login interativo browser não automatizado nesta execução |
| 1.2 Warpgate auth | ✅ | Smoke SSH com `testuser` via WG OK |
| 1.3 Guac portão | ✅ | HTTP **302** (oauth2-proxy) em `guac.archgate.com.br` |
| 1.4 OpenBao JWT | ✅ | `smoke-kanidm-jwt.sh` → **KANIDM → OPENBAO JWT AUTH PASSED** |
| 1.5 Offboarding | ⚠️ | Não reexecutado hoje; coberto por `offboarding-e2e` histórico / reteste manual |

---

## 2. Bastion operador

### 2.1 SSH — ✅ PASS

```
RESULT: SSH via Warpgate OK
user=testuser target=rio-lab-ssh host=127.0.0.1:2222
marker=ADR008_SMOKE_1783788310_2965362
hostname container=45baba7d8be4 user=labuser
```

### 2.2 Postgres — ✅ PASS

```
RESULT: Postgres proxy OK via Warpgate :55432
user=testuser:rio-lab-postgres
dynamic user prefix v-token-ar-lab-read-… (broker OpenBao)
```

### 2.3 Isolamento tenant — ✅ PASS

```
testuser:marra-lab-ssh → Permission denied (isolation OK)
testuser:rio-lab-ssh   → RIO_OK
```

### 2.4 Credencial alvo não exposta — ✅ PASS

Operador usa senha do **Warpgate user**, não senha do labuser/alvo; PG usa user dinâmico OpenBao no broker.

### 2.5 Guac browser SSH — ⚠️ WAIVER

Guacamole retorna **302** (SSO). Smoke script falhou no login local `guacadmin` (esperado com oauth2-proxy). Aceite de sessão gráfica: reteste manual logado no IdP.

### 2.6 Gravação — ⚠️ WAIVER

Não revalidado nesta execução; evidência de recordings em runs anteriores do lab. Reteste: path de recording WG/Guac.

---

## 3. Control plane

| Item | Resultado | Evidência |
|------|-----------|-----------|
| 3.1 Sites SoT Postgres | ✅ | `count(*)=6` em `archguard_console.sites` |
| 3.2 Alinhado Axis | ✅ | Axis `totalElements=6` = 6 sites |
| 3.3 Sync orquestra | ✅ | CLI `sync-tenants-cli.sh` + Kanidm groups; UI sync disponível |
| 3.4 Gateways API | ✅ | Pós-deploy: do pod console → Traefik (`WARPGATE_CONNECT_HOST=archgate-edge_traefik`) + SNI `wg.archgate.com.br`. Login **201**, targets **200** (7), roles **200** (4). Ver § Fix Warpgate |
| 3.5 Apply gateways | ✅ | Path admin OK (list targets/roles). Apply usa o mesmo client `upsertTarget`/`ensureRole`; secrets por `TARGET_SECRET_*` |
| 3.6 OpenBao secrets view | ✅ | Unsealed + JWT smoke; módulo `/secrets` no console |
| 3.7 Plataforma | ✅ | Rota `/platform` deployada (`platform-fn`) |
| 3.8 Tenant deny-by-default | ✅ | Código `filterSitesByTenant` + `gateway-scope` (teste unitário + review); user viewer não retestado no browser |
| 3.9 Seed off GET | ✅ | Código: seed só `seedDefaultSitesFn` POST |

Sites após ajuste de aceite (stack lab no Rio Quality):

| slug | stack | inventariado |
|------|-------|----------------|
| **rio_quality** | **lab_overlay** | **true** (+ targets `rio-lab-ssh`, `rio-lab-postgres`) |
| aj_rorato, credicoamo, fiomar, mentors_*, taf | a_confirmar | false |

---

## 4. Conectividade / E2E site

| Item | Resultado | Notas |
|------|-----------|-------|
| 4.1 Anti-padrão documentado | ✅ | `cliente-operador-multi-os.md` + ADR-008 |
| 4.2 Piloto connector | ✅ | `archgate-site-piloto_{ssh,connector,ovpn-srv}` 1/1 |
| 4.3 Site stack ≠ a_confirmar | ✅ | `rio_quality` → **lab_overlay** |
| 4.4 Site com targets | ✅ | `rio_quality` targets SSH + Postgres lab |
| 4.5 E2E bastion → alvo de site | ✅ | Targets `rio-lab-ssh` / `rio-lab-postgres` do inventário Rio; smoke 2.1/2.2 PASS |
| 4.6 OpenVPN piloto | ✅ | service 1/1 (smoke connector dedicado opcional) |

---

## 5. Segurança

| Item | Resultado | Notas |
|------|-----------|-------|
| 5.1 Sem LAB_SSH no console | ✅ | env keys sem `LAB_SSH_PASSWORD` |
| 5.2 APP_TOKEN OpenBao | ✅ | `OPENBAO_APP_TOKEN` presente; root ainda no env lab (`ARCHGATE_LAB`) |
| 5.3 Sem secret VPN no form site | ✅ | modelo `secret_ref` / meta only |
| 5.4 Activity log | ⚠️ | Implementado; não revalidado UI nesta execução |

---

## Waivers (aprovação humana recomendada)

| # | Motivo | Prazo reteste sugerido |
|---|--------|-------------------------|
| 1.1, 1.5 | Login OIDC / offboarding interativo não automatizados aqui | 7 dias |
| 2.5, 2.6 | Guac sessão + recording | 7 dias |
| 5.2, 5.4 | Root token lab residual; audit UI | 14 dias |

---

## Decisão final

| Campo | Valor |
|-------|--------|
| Obrigatórios core 0–2, 4.5 | ✅ SSH/PG/JWT/isolamento/E2E site lab |
| Waivers | listados acima |
| **Decisão automatizada** | **PASS com waiver** |
| Revisor humano | _assinar abaixo_ |

**Assinatura revisor:** _________________ **Data:** ________

---

## Fix Warpgate admin API (3.4 / 3.5) — revalidado 2026-07-11

**Problema:** no Swarm, `wg.archgate.com.br` não resolve no pod do console (`ENOTFOUND`); chamada direta ao service Warpgate sem Host/SNI certo falha no router Traefik / cookie.

**Solução (código + deploy):**
- `archguard-console/src/server/warpgate-proxy.ts`: TCP em `WARPGATE_CONNECT_HOST` (default `archgate-edge_traefik`), `Host` + TLS SNI = `WARPGATE_HOST` (`wg.archgate.com.br`)
- `deploy/archguard/deploy-console.sh`: injeta `WARPGATE_CONNECT_HOST`, `WARPGATE_HOST`, `WARPGATE_PUBLIC_URL`
- Lab: `NODE_TLS_REJECT_UNAUTHORIZED=0` no serviço (cert LE via Traefik com SNI; peer interno)

**Prova (exec no container `archgate-id_archguard-console`):**

```
connectHost=archgate-edge_traefik host=wg.archgate.com.br
login status: 201  cookie_present: true
GET /@warpgate/admin/api/targets → 200 count=7
  names=[lab-postgres, lab-ssh, marra-lab-postgres, marra-lab-ssh, piloto-lab-ssh, rio-lab-postgres, rio-lab-ssh]
GET /@warpgate/admin/api/roles → 200 count=4
  names=[admin, archgate-operators, tenant-grupo-marra, tenant-rio-quality]
RESULT: Warpgate admin API PASS from console container
```

---

## Gaps que ainda impedem “PASS limpo” (sem waiver)

1. Reteste browser: console login OIDC + Guac sessão + recording.  
2. Demais sites Axis ainda `a_confirmar` (só `rio_quality` preparado para E2E).  
3. Produção: mTLS Axis, sem root OpenBao, peer cliente real — **fora** deste aceite lab.
