# Spec Delta — ephemeral-credentials

## MODIFIED Requirements

### Requirement: Credencial Dinâmica de Banco
O sistema SHALL conceder acesso a bancos via credencial dinâmica com TTL, cobrindo PostgreSQL nativamente e **Oracle conforme a decisão do ADR-001**, revogada ao fim do lease.

#### Scenario: Credencial de banco com ciclo de vida (PostgreSQL)
- **WHEN** um desenvolvedor solicita acesso ao PostgreSQL de um alvo
- **THEN** o OpenBao cria um usuário temporário com permissões mínimas e TTL
- **AND** ao expirar o lease, a credencial é revogada automaticamente

#### Scenario: Credencial de banco Oracle
- **WHEN** um desenvolvedor solicita acesso a um banco Oracle de cliente
- **THEN** o sistema fornece acesso pelo mecanismo definido no ADR-001 (engine dinâmico, se validado, ou fallback gerenciado com TTL)
- **AND** a credencial não é de longa vida nem exposta ao desenvolvedor
