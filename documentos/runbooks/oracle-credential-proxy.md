# Runbook — Oracle credential proxy (W3 / ADR-001)

| Campo | Valor |
|-------|--------|
| ADR | [ADR-001](../../adr/ADR-001-oracle-database-via-java-proxy.md) |
| Spec | `openspec/changes/add-oracle-credential-proxy/` |
| Proxy | `services/oracle-proxy/` |
| Plugin scaffold | `services/openbao-oracle-plugin/` |

## Arquitetura

```
OpenBao ── Go plugin (dbplugin v5) ──mTLS──> oracle-proxy (Java/ojdbc) ──> Oracle
```

Emissão dinâmica de usuário; **transporte** até o banco (VPN/connector) é W2/rede — separado.

## Estado (2026-07-17)

| Peça | Status |
|------|--------|
| Proxy Spring + statement renderer ({{username}}) | **done** (mock executor) |
| Testes mock create/delete + SQL history | unitários |
| JDBC executor | **done** (profile `-Pojdbc`, `oracle.proxy.mock=false`) |
| ojdbc dependency | profile Maven `ojdbc` |
| Plugin gRPC OpenBao | pendente; CLI + `client` package HTTP + mTLS env |
| mTLS | skeleton `application-mtls.yml` + `gen-mtls-lab-certs.sh` |
| E2E Oracle Rio/Consinco | pendente ambiente |
| Smoke mock HTTP | `deploy/oracle-proxy/smoke-oracle-proxy-mock.sh` |

## Local mock

```bash
cd services/oracle-proxy
mvn -q test
mvn -q spring-boot:run
# outro terminal
bash deploy/oracle-proxy/smoke-oracle-proxy-mock.sh
cd services/openbao-oracle-plugin && go run . -op create -user v_x -pass 'Secret123!'
```

## mTLS lab

```bash
bash deploy/oracle-proxy/gen-mtls-lab-certs.sh /tmp/oracle-mtls
# run proxy with profile mtls and keystore mounts
# client:
export ORACLE_PROXY_CLIENT_CERT=/tmp/oracle-mtls/client.crt
export ORACLE_PROXY_CLIENT_KEY=/tmp/oracle-mtls/client.key
export ORACLE_PROXY_CA_CERT=/tmp/oracle-mtls/ca.crt
export ORACLE_PROXY_URL=https://127.0.0.1:9040
go run . -op create -user v_mtls -pass 'Secret123!'
```

## Produção (futuro)

1. Habilitar ojdbc no `pom.xml`.  
2. `ORACLE_PROXY_MOCK=false` + JDBC URL admin mínimo.  
3. Plugin catalog OpenBao + role `oracle-readonly`.  
4. mTLS plugin↔proxy.  
5. Smoke lease + connect + revoke.

## N/A?

Se nenhum cliente Oracle no horizonte: marcar W3-ORACLE09 N/A assinado no plano 100%.
