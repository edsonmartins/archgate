# Spec Delta — access-console

## MODIFIED Requirements

### Requirement: Lista de Conexões Autorizadas
O console SHALL apresentar a cada operador somente as conexões que ele está autorizado a usar, **dentro da UnifiedUI**, permitindo abrir a sessão remota embutida sem UI de terceiros.

#### Scenario: Operador abre conexão na UnifiedUI
- **WHEN** um operador abre a lista de conexões
- **THEN** vê somente os targets permitidos ao seu papel e tenant
- **AND** pode abrir a sessão remota diretamente dentro da UnifiedUI
- **AND** a UI stock do Guacamole não faz mais parte do fluxo do operador
