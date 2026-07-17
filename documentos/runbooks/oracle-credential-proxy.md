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
| Proxy Spring esqueleto + mock API | **scaffold** |
| Testes mock create/delete | unitários no módulo |
| ojdbc real | pendente (pom comentado) |
| Plugin gRPC OpenBao | pendente (CLI HTTP helper only) |
| mTLS | pendente |
| E2E Oracle Rio/Consinco | pendente ambiente |

## Local mock

```bash
cd services/oracle-proxy
mvn -q test
mvn -q spring-boot:run
# outro terminal
cd services/openbao-oracle-plugin && go run . -op create -user v_x -pass 'Secret123!'
```

## Produção (futuro)

1. Habilitar ojdbc no `pom.xml`.  
2. `ORACLE_PROXY_MOCK=false` + JDBC URL admin mínimo.  
3. Plugin catalog OpenBao + role `oracle-readonly`.  
4. mTLS plugin↔proxy.  
5. Smoke lease + connect + revoke.

## N/A?

Se nenhum cliente Oracle no horizonte: marcar W3-ORACLE09 N/A assinado no plano 100%.
