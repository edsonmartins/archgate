# Proposal — Add Oracle Credential Proxy

## Why

O ADR-001 decidiu que o acesso a credencial dinâmica Oracle se dá por um **proxy Java** atendendo à interface de plugin de banco do OpenBao, com driver **JDBC thin (ojdbc)** — Java puro, sem bibliotecas nativas, com suporte a TNS/failover. Esta mudança implementa esse proxy e destrava a célula Oracle da matriz de protocolo, resolvendo o bloqueador da Fase 3 para clientes Consinco/Oracle (Rio Quality).

## What Changes

- **Plugin Go fino** implementando a interface `dbplugin` v5 do OpenBao (NewUser, UpdateUser, DeleteUser, RotateRoot), registrado no catálogo de plugins.
- **Proxy Java (Spring Boot 3.x / Java 21)** que executa as operações no Oracle via JDBC thin.
- **Canal OpenBao↔proxy com mTLS**.
- **Roles dinâmicos Oracle** no OpenBao (creation/revocation statements, TTL, username_template ajustado ao limite Oracle).
- **Usuário administrativo Oracle** dedicado com privilégio mínimo.

## Impact

- **Nova capability:** `oracle-credential-proxy`.
- **Cumpre:** o cenário Oracle da capability `ephemeral-credentials` (introduzido em `add-network-mesh`).
- **Componentes:** plugin Go, proxy Java, OpenBao, Oracle-alvo (Consinco).
- **Depende de:** Fase 2 (`add-ephemeral-credentials`) para o Database Secrets Engine; ADR-001 (aceito).
- **Sequência:** implementar antes/junto da Fase 3, pois é pré-requisito do sign-off Oracle.
- **Escopo:** cobre a **emissão** de credencial. O **transporte** (dev alcança o Oracle) segue a decisão de acesso da Fase 3 (`network-reachability`).
