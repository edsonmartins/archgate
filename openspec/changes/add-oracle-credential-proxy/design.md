# Design — Add Oracle Credential Proxy

## Contexto
Implementa a decisão do ADR-001: credencial dinâmica Oracle via proxy Java atendendo à interface de plugin de banco do OpenBao. Resolve o bloqueador da Fase 3 para clientes Oracle sem contaminar a imagem do OpenBao com bibliotecas nativas.

## Arquitetura

```
OpenBao ──(dbplugin v5, Go)──> Plugin Go fino ──HTTP/gRPC (mTLS)──> Proxy Java (Spring Boot) ──JDBC thin──> Oracle
```

O plugin Go apenas traduz a interface `dbplugin` v5 em chamadas ao proxy. Toda a lógica Oracle (executar DDL de usuário via JDBC) vive no proxy Java. As statements de criação/revogação vêm da configuração do role no OpenBao, mantendo o proxy genérico (executor de statements Oracle), não um gerador de DDL hardcoded.

## Decisões técnicas

### D1 — JDBC thin (ojdbc), não Instant Client
O driver thin é Java puro e suporta descritores TNS. Elimina a necessidade de bibliotecas nativas (evita o problema da imagem Alpine e o ônus do godror) e resolve o failover multi-instância que o go-ora não faz.

### D2 — Statements na config do role, proxy genérico
As creation/revocation statements ficam no role do OpenBao (com substituição de `{{username}}`, `{{password}}`, `{{expiration}}`). O proxy executa; não conhece regras de negócio. Facilita manutenção e auditoria.

### D3 — mTLS obrigatório no canal
O plugin Go e o proxy Java autenticam-se mutuamente. O canal transporta operações que criam/removem usuários de banco — não pode ser aberto.

### D4 — Usuário administrativo Oracle de privilégio mínimo
O proxy usa um usuário Oracle dedicado com CREATE/ALTER/DROP USER e GRANT — nunca DBA pleno. Segredo injetado com segurança; rotate-root habilitado.

### D5 — Escopo é emissão, não transporte
Este pacote entrega a **emissão** da credencial. Como o dev alcança o Oracle (injeção via proxy dedicado vs. malha NetBird + credencial efêmera em mãos) é decisão da capability `network-reachability` (Fase 3). Aqui a credencial é dinâmica, com TTL e identity-gated de qualquer forma.

## Riscos e mitigações
- **Limite de identificador Oracle** → `username_template` ajustado à versão-alvo (tarefa 4.3/1.7).
- **PDB/CDB Consinco** → validar conexão ao serviço/PDB correto (1.3).
- **Usuários órfãos** → reconciliação periódica (5.5).
- **Credencial administrativa comprometida** → privilégio mínimo + rotate-root + mTLS.

## Fora de escopo
Transporte/roteamento de rede (Fase 3), demais protocolos, UnifiedUI (Fase 4).
