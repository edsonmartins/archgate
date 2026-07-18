# OpenBao Oracle plugin (ADR-001)

Thin **database plugin v5** (Go) that forwards Create/Update/Delete user to
`services/oracle-proxy` over HTTP(S)/mTLS. No Oracle client libraries in this
binary or in the OpenBao image.

## Modes

### Plugin (production)

OpenBao/Vault spawns this binary via the database plugin runner (gRPC / go-plugin):

```bash
go build -o openbao-oracle-plugin .
# install into OpenBao plugin_directory, then:
bash deploy/oracle-proxy/register-plugin.sh
```

Config keys on `database/config/*`:

| Key | Meaning |
|-----|---------|
| `url` / `proxy_url` | Base URL of oracle-proxy |
| `require_mtls` | `true` → require client cert env on OpenBao host |

Env on OpenBao host (plugin process inherits):

| Env | Purpose |
|-----|---------|
| `ORACLE_PROXY_URL` | Fallback proxy URL |
| `ORACLE_PROXY_REQUIRE_MTLS` | Force mTLS |
| `ORACLE_PROXY_CLIENT_CERT` / `_KEY` / `_CA_CERT` | mTLS PEM paths |

### Lab CLI

```bash
ORACLE_PLUGIN_CLI=1 ./openbao-oracle-plugin -op type
./openbao-oracle-plugin -cli -op init-smoke -proxy http://127.0.0.1:9040
./openbao-oracle-plugin -cli -op create -user v_demo -pass 'Secret123!'
```

Smoke: `bash deploy/oracle-proxy/smoke-plugin-cli.sh`

## Layout

| Path | Role |
|------|------|
| `main.go` | ServeMultiplex + CLI |
| `oracle/database.go` | `dbplugin.Database` impl |
| `client/` | HTTP client + mTLS |

## Next (ops, not code)

1. Real Oracle JDBC on proxy (`ORACLE_PROXY_MOCK=false`)
2. Register plugin SHA on Hostinger OpenBao
3. JWT role Kanidm → `database/creds/oracle-readonly`
