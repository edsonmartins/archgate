# Design — Org Credential Broker

## Contexto

Implementa o [ADR-013](../../../adr/ADR-013-org-credential-broker.md): módulo no Manager para contas da IntegrAllTech (cloud, lojas, produtos), com OpenBao como SoT de segredo e archguard como SoT de identidade.

## Arquitetura

```
┌─────────────┐     OIDC      ┌──────────────────┐
│  Operador / │──────────────▶│ ArchGate Manager │
│  Gestor     │               │  /org-accounts   │
└─────────────┘               └────────┬─────────┘
                                       │ server-side only
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
              ┌──────────┐      ┌──────────┐      ┌─────────────┐
              │  archguard  │      │ Console  │      │  OpenBao    │
              │ groups + │      │  DB SoT  │      │  KV org/*   │
              │  perms   │      │ metadata │      │  (secret)   │
              └──────────┘      └──────────┘      └─────────────┘
                                       │
                                       ▼
                               activity_log / audit
```

**Fluxo checkout (MVP):**

1. `GET /api/org/v1/accounts` — metadados (sem secret).  
2. `POST /api/org/v1/accounts/:id/checkout` — `{ reason, ttl_seconds }`.  
3. Server valida RBAC + dual-control se P0.  
4. Server lê OpenBao com **app token**; devolve secret **uma vez** na response (HTTPS sessão cookie).  
5. Audit + opcional notificação.  
6. `POST …/checkin` ou TTL encerra (métrica; não “apaga da memória humana”, mas fecha janela formal).

## Modelo de dados (console DB)

```
OrgAccount
  id (uuid)
  slug (unique)           # apple-appstore-integrall
  name                    # App Store Connect · IntegrAllTech
  category                # cloud | store | product_admin | vendor | other
  product                 # vendax | archflow | brainsentry | null
  url
  login_hint              # e-mail da conta (não é o segredo)
  auth_kind               # password | api_key | oidc | totp_password
  secret_ref              # path OpenBao, ex. secret/data/org/store/apple-appstore
  criticality             # P0 | P1 | P2
  owner_group             # archguard group slug
  requires_dual_control   # bool (default true se P0)
  notes
  runbook_url
  created_at, updated_at, updated_by
```

```
OrgCheckout
  id
  account_id
  principal               # username archguard
  reason
  ttl_seconds
  status                  # pending | active | denied | expired | checked_in
  approved_by             # null se não dual-control
  created_at, expires_at, closed_at
```

Metadados no **PostgreSQL/SQLite do console** (como sites).  
Material secreto **só** no OpenBao.

## OpenBao

| Path | Uso |
|------|-----|
| `secret/data/org/cloud/*` | GCP, etc. |
| `secret/data/org/store/*` | Apple, Play |
| `secret/data/org/product/*` | admins de produto |

Payload mínimo KV:

```json
{
  "password": "…",
  "username": "…",
  "api_key": "…",
  "totp_seed": null,
  "recovery_note": "ver cofre físico / dual-control"
}
```

Policy do app token do console: `read` em `secret/data/org/*` + `list` nos mounts; **write** só role `org_accounts:admin` via path allowlist server-side.

## RBAC (console permissions)

| Permission | Capacidade |
|------------|------------|
| `org_accounts:read` | Listar metadados |
| `org_accounts:checkout` | Solicitar/usar checkout |
| `org_accounts:approve` | Dual-control P0 |
| `org_accounts:admin` | CRUD conta + secret_ref / write OpenBao |

Mapear grupos archguard (ex.: `archguard_users` → read+checkout limitado; `archguard_super_admins` → admin+approve). Ajuste fino por `owner_group` / product tag na implementação.

## Decisões técnicas

### D1 — Checkout, não autofill
MVP não injeta senha em Google/Apple. Operador cola no portal. Audit + TTL compensam.

### D2 — Server-side OpenBao only
Mesmo padrão Warpgate/Guac proxies: browser nunca vê `OPENBAO_APP_TOKEN`.

### D3 — Connect fora do MVP
Evita vault no endpoint. OCB-5 opcional: link “Abrir no Manager”.

### D4 — Dual-control assíncrono
Checkout P0 cria `pending`; aprovador notificado; só então reveal. Timeout cancela.

### D5 — Preferir keys na evolução
OCB-3: API keys Play/Apple/GCP no KV; password só break-glass.

## Riscos e mitigações

| Risco | Mitigação |
|-------|-----------|
| Copy de senha para chat | TTL curto, dual-control P0, cultura + audit |
| OpenBao sealed | Falha fechada; runbook unseal |
| Conta ainda só no 1Password pessoal | OCB-0 inventário + migração obrigatória P0 |
| Confundir com target de cliente | Namespace UI “Contas da org” vs “Sites” |

## Fora de escopo

Password manager full; proxy SaaS Google/Apple; vault Connect; dados de cartão/LGPD de cliente no mesmo módulo sem classificação.
