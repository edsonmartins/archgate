# ArchGate Oracle Proxy (ADR-001)

Spring Boot 3 / Java 21 service that executes OpenBao Database plugin operations against **Oracle via JDBC thin** (no Instant Client in OpenBao).

```
OpenBao ── Go plugin ──HTTPS/mTLS──> this service ──ojdbc──> Oracle
```

## Modes

| Mode | Env | Behavior |
|------|-----|----------|
| **Mock** (default) | `ORACLE_PROXY_MOCK=true` | In-memory users; no Oracle |
| **JDBC** | `ORACLE_PROXY_MOCK=false` + `ORACLE_JDBC_*` | Real DDL (ojdbc dependency enable in pom) |

## API

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/v1/oracle/users` | NewUser |
| POST | `/v1/oracle/users/update` | UpdateUser |
| POST | `/v1/oracle/users/delete` | DeleteUser |
| POST | `/v1/oracle/root/rotate` | RotateRootCredentials |
| GET | `/actuator/health` | Health |

## Local

```bash
cd services/oracle-proxy
mvn -q test
mvn -q spring-boot:run
curl -sS -X POST localhost:9040/v1/oracle/users \
  -H 'Content-Type: application/json' \
  -d '{"username":"v_demo","password":"x"}'
```

## Tasks OpenSpec

See `openspec/changes/add-oracle-credential-proxy/tasks.md` (1.x scaffold = this module).
