# Evidence — ArchGate Connect H4 (OIDC) + H5 (smoke macOS lab)

| Campo | Valor |
|-------|--------|
| **Data** | 2026-07-19 |
| **Host** | macOS darwin/arm64 (notebook operador) |
| **CLI** | `archgate 0.2.0-dev` (`clients/archgate-connect`) |
| **ADR** | ADR-008A · Fase H (PLAN-IMPLEMENTACAO-RESTANTE) |
| **Operador** | smoke automatizado (lab) + preflight OIDC |

## Resumo

| ID | Resultado | Escopo |
|----|-----------|--------|
| **H4** | **PASS (preflight)** | Discovery + client secret presente + token endpoint vivo + shape PKCE. Login browser interativo **não** automatizado nesta evidence. |
| **H5 mock** | **PASS** | `68-smoke-archgate-connect.sh` com `ARCHGATE_MOCK=1` |
| **H5 live lab** | **PASS** | `ARCHGATE_MOCK=0` + `login --lab` + BFF live + bastion TCP OPEN + catálogo 10 entries sem IPs internos |

Critério **Bastion, not VPN** (happy path Connect): catálogo e `print-ssh` apontam só bastion ArchGate (`217.196.60.108:2222`), não IPs de alvo do cliente.

---

## H4 — OIDC preflight (não interativo)

### Checks

1. **Discovery** `GET …/oauth2/openid/archgate-connect/.well-known/openid-configuration` → **HTTP 200**
   - issuer: `https://id.archgate.com.br/oauth2/openid/archgate-connect`
   - grant_types: `authorization_code`, token-exchange
   - **device_authorization_endpoint:** ausente (esperado; CLI usa PKCE browser)
2. **Client secret local:** `~/.config/archgate/oidc.env` existe e define `ARCHGATE_OIDC_CLIENT_SECRET` (valor **não** copiado para evidence)
3. **Token endpoint** `POST /oauth2/token` com code inválido → **HTTP 401** (endpoint alcançável; rejeita grant inválido)
4. **URL PKCE** montável com `client_id=archgate-connect` e `redirect_uri=http://127.0.0.1:8765/callback`

### Residual H4

- [ ] Login browser completo (`archgate login` SSO) com captura de bootstrap 200 sob token OIDC real (humano ou CI com device harness futuro).
- [ ] Refresh token automático (ainda não implementado no CLI).

Comando reprodutível:

```bash
./clients/archgate-connect/scripts/smoke-h4-h5.sh --h4-only
```

---

## H5 — Smoke macOS (mock)

```text
ARCHGATE_MOCK=1 ./archgate-devops/scripts/68-smoke-archgate-connect.sh
→ PASS 68-smoke-archgate-connect
```

Cobertura: version, login --lab, status, ls, print-ssh, config apply, doctor, db snippet, logout.  
`print-ssh`: `uat-op-a:rio-lab-ssh@217.196.60.108` (nunca nickname lab no user Warpgate).

---

## H5 — Smoke live lab (BFF real)

```text
ARCHGATE_MOCK=0
ARCHGATE_CONFIG_DIR=<tmp>
archgate login --lab --user smoke.h5
archgate status --json   → session=true auth=lab connections=10 mock=false
archgate ls --json       → 10 connections, tenant_rio_quality, sem 10.x/192.168 em campos
archgate doctor --json   → auth/warpgate_user/ssh_bastion/pg_bastion/openssh/catalog OK
archgate print-ssh rio-lab-ssh
  → ssh -p 2222 … 'uat-op-a:rio-lab-ssh@217.196.60.108'
archgate logout
```

### Doctor (live)

| Check | OK | Detail |
|-------|-----|--------|
| auth | yes | smoke.h5 |
| warpgate_user | yes | uat-op-a |
| ssh_bastion | yes | 217.196.60.108:2222 OPEN |
| pg_bastion | yes | 217.196.60.108:55432 OPEN |
| openssh_cli | yes | on PATH |
| catalog | yes | 10 connections |

### Assertions automatizadas

- session lab + mock=false  
- ≥1 conexão no catálogo  
- print-ssh contém `ssh -p` e host bastion  
- JSON de connections **sem** `10.0.` / `192.168.` em campos do catálogo  

---

## Ambiente notebook (transparência)

No momento da evidence o Mac **também** tinha interfaces/processos de VPN **fora do Connect** (ex.: `openfortivpn`/`ppp0`, WireGuard “macmini”).  

Isso **não** invalida o happy path do Connect (BFF HTTPS + bastion TCP públicos), mas é **residual H6 / higiene**: o critério de produto “sem Forti/OpenVPN do **cliente** no notebook” para o dia a dia Rio ainda deve ser reforçado operacionalmente (desligar VPN cliente quando peer VPS + Connect bastam).

Connect **não** instalou nem configurou esses peers nesta smoke.

---

## Artefatos

| Artefato | Onde |
|----------|------|
| CLI smoke mock | `archgate-devops/scripts/68-smoke-archgate-connect.sh` |
| H4+H5 local | `clients/archgate-connect/scripts/smoke-h4-h5.sh` |
| Código | `clients/archgate-connect/` |
| Runbook | `documentos/runbooks/archgate-connect.md` |

## Conclusão

- **H4 preflight:** client Kanidm `archgate-connect` vivo; path PKCE documentado e alcançável.  
- **H5:** lab mock + live BFF PASS no macOS sem materializar VPN de cliente via Connect.  
- **Próximo:** login SSO interativo com evidence de token; H6 migração diária Rio; codesign.
