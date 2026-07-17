# ArchGate Orchestration (W4-ORCH)

Serviço de ciclo de vida Axis → plataforma (provision / grant / revoke multi-componente).

Contratos: [`documentos/runbooks/orchestration-api-contracts.md`](../../documentos/runbooks/orchestration-api-contracts.md).

## Stack

- Spring Boot 3.4 / Java 21  
- Modo **mock** (default): adapters in-memory `kanidm`, `warpgate`, `guacamole`, `openbao`  
- Live clients (Kanidm REST, Warpgate admin, Guac provision, OpenBao leases): TBD

## API

| Método | Path | Efeito |
|--------|------|--------|
| POST | `/orchestration/v1/users/provision` | person + groups em todos adapters |
| POST | `/orchestration/v1/access/grant` | target WG (+ OpenBao) |
| POST | `/orchestration/v1/users/revoke` | **one-shot** offboarding (idempotente) |
| POST | `/orchestration/v1/tenants/sync` | stub sync tenants |
| GET | `/orchestration/v1/status/last` | última orquestração global |
| GET | `/orchestration/v1/status/users/{username}` | última op do user |

Porta default: `8090` (`ORCH_PORT`).

## Dev

```bash
cd services/orchestration
mvn -q test
mvn -q spring-boot:run
# curl -s localhost:8090/actuator/health
```

## Smoke

```bash
curl -s -X POST localhost:8090/orchestration/v1/users/provision \
  -H 'Content-Type: application/json' \
  -d '{"tenant_slug":"rio_quality","username":"dev.silva","email":"a@b.c","profile":"operator"}'
```

## Segurança

- **Não** expor na internet sem mTLS / rede admin.  
- Tokens admin só server-side (nunca SPA — ADR-006 / W4-UI05).  
- Axis chama com credencial de serviço.
