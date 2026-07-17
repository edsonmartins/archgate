# OpenBao Oracle plugin (thin client scaffold)

ADR-001 task **2.x** — thin Go side that talks to `services/oracle-proxy`.

## Current scope (scaffold)

- CLI HTTP client for lab (`-op create|update|delete|rotate-root`)
- **Not yet** a full `dbplugin` v5 gRPC binary registered in OpenBao

## Next

1. Implement vault/openbao `database/dbplugin` gRPC server.
2. Map NewUser → `POST /v1/oracle/users`, etc.
3. mTLS to proxy.
4. `sys/plugins/catalog` + database connection config.

## Lab smoke (with proxy mock running)

```bash
# terminal 1
cd services/oracle-proxy && mvn -q spring-boot:run

# terminal 2
cd services/openbao-oracle-plugin
go run . -op create -user v_demo1 -pass 'Secret123!'
go run . -op delete -user v_demo1
```
