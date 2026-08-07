# ArchGate Orchestration (W4-ORCH)

Serviço de ciclo de vida Axis → plataforma (provision / grant / revoke multi-componente).

Contratos: [`documentos/runbooks/orchestration-api-contracts.md`](../../documentos/runbooks/orchestration-api-contracts.md).

## Stack

- Spring Boot 3.4 / Java 21  
- Modo **mock** (default): adapters in-memory `archguard`, `warpgate`, `guacamole`, `openbao`
- Modo **live** (`ORCH_MODE=live`): HTTP adapters + `ORCH_DRY_RUN=true` por default (só log)

## API

| Método | Path | Efeito |
|--------|------|--------|
| POST | `/orchestration/v1/users/provision` | person + groups em todos adapters |
| POST | `/orchestration/v1/access/grant` | target WG (+ OpenBao) |
| POST | `/orchestration/v1/users/revoke` | **one-shot** offboarding (idempotente) |
| POST | `/orchestration/v1/tenants/sync` | stub sync tenants |
| POST | `/orchestration/v1/identities/session-context` | resolve identidade/memberships no ArchGuard |
| POST | `/orchestration/v1/webhooks/axis` | Axis events + `Idempotency-Key` |
| GET | `/orchestration/v1/status/last` | última orquestração global |
| GET | `/orchestration/v1/status/users/{username}` | última op do user |

Porta default: `8090` (`ORCH_PORT`).

## Live env

```bash
export ORCH_MODE=live
export ORCH_DRY_RUN=true   # false só com tokens reais
export ORCH_ARCHGUARD_ENABLED=true ORCH_ARCHGUARD_URL=… ORCH_ARCHGUARD_TOKEN=…
export ORCH_WG_ENABLED=true ORCH_WG_URL=… ORCH_WG_TOKEN=…
# guacamole / openbao idem
```

Paths HTTP dos adapters são **intent** (alinhar à API real de cada versão em lab).

`/orchestration/v1/identities/session-context` chama
`POST /api/v1/service/session-context` no ArchGuard SaaS (`app.archguard.com.br`).
O corpo contém somente `{"subject":"..."}` e a resposta traz `identity_id`,
`identity_status` e memberships. O token `ORCH_ARCHGUARD_TOKEN` é enviado
exclusivamente no backend; nunca deve chegar à SPA.

## Dev

```bash
cd services/orchestration
mvn -q test
mvn -q spring-boot:run
# curl -s localhost:8090/actuator/health
```

## Smoke

```bash
# com serviço rodando:
bash deploy/validation/smoke-orchestration-mock.sh

curl -s -X POST localhost:8090/orchestration/v1/users/provision \
  -H 'Content-Type: application/json' \
  -d '{"tenant_slug":"rio_quality","username":"dev.silva","email":"a@b.c","profile":"operator"}'
```

## Segurança

- **Não** expor na internet sem mTLS / rede admin.  
- Tokens admin só server-side (nunca SPA — ADR-006 / W4-UI05).  
- Axis chama com credencial de serviço.
