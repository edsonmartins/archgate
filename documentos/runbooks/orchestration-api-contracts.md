# Contratos de orquestração — Axis ↔ ArchGate (W4-ORCH)

Rascunho de API desejada (ADR-004). Implementação pode viver no console BFF ou serviço `orchestration`.

## Operações

### `POST /orchestration/v1/users/provision`

```json
{
  "tenant_slug": "rio_quality",
  "username": "dev.silva",
  "email": "dev.silva@integrall.tech",
  "profile": "operator",
  "groups": ["tenant_rio_quality", "archguard_users"]
}
```

Efeito: Kanidm person + memberships (+ opcional WG role / Guac user).

### `POST /orchestration/v1/access/grant`

```json
{
  "username": "dev.silva",
  "target": "rio-app-ssh",
  "ttl": "8h"
}
```

Efeito: bind role/target Warpgate; policy OpenBao se aplicável.

### `POST /orchestration/v1/users/revoke`

```json
{
  "username": "dev.silva",
  "reason": "offboarding"
}
```

Efeito: **revogar_tudo** — expire Kanidm, drop leases OpenBao, remove roles WG/Guac (idempotente).

### `POST /orchestration/v1/tenants/sync`

Dispara sync Axis → sites SoT + `tenant_*` (já parcialmente no lab `sync-tenants-cli` / console).

### `POST /orchestration/v1/webhooks/axis`

Webhook Axis com header `Idempotency-Key` (W4-ORCH05).

```json
{
  "event": "user.offboard",
  "username": "dev.silva",
  "reason": "left company"
}
```

Eventos: `user.provision` | `access.grant` | `user.offboard` | `tenants.sync` (aliases aceitos).

## Princípios

| Princípio | Nota |
|-----------|------|
| Idempotência | Re-run não duplica person/role |
| Audit | Toda mutação → activity_log |
| Sem senha de alvo | Só secret_ref / OpenBao |
| Axis SoT tenants | Consola não inventa cliente |

## Estado

| Op | Lab hoje | W4 target |
|----|----------|-----------|
| sync tenants | CLI + UI Spring | API estável + audit |
| provision user | manual / SA Kanidm | API one-shot |
| grant access | apply targets manual | API |
| revoke all | offboarding-e2e IdP | multi-componente API |

## Scaffold (2026-07-17)

Implementação mock em `services/orchestration` (Spring Boot):

- `POST …/users/provision|revoke`, `…/access/grant`, `…/tenants/sync`
- `GET …/status/last`, `…/status/users/{username}`
- Adapters mock: kanidm, warpgate, guacamole, openbao (idempotência de revoke coberta em testes)

Live: trocar `MockComponentAdapter` por clients reais; manter a mesma API.
