# Spec Delta — high-availability

## ADDED Requirements

### Requirement: OpenBao em Alta Disponibilidade
O sistema SHALL operar o OpenBao em modo HA com auto-unseal seguro.

#### Scenario: Falha de nó do OpenBao
- **WHEN** um nó do OpenBao falha
- **THEN** a emissão de credenciais continua por outro nó sem intervenção manual

### Requirement: archguard Replicado
O sistema SHALL operar o archguard com replicação.

#### Scenario: Falha de nó do archguard
- **WHEN** um nó do archguard falha
- **THEN** a autenticação continua disponível por outro nó

### Requirement: Persistência Externa e Gateways Stateless
O sistema SHALL usar persistência externa para Warpgate e Guacamole e SHALL operar os gateways de forma stateless atrás do Traefik onde possível.

#### Scenario: Reinício de gateway sem perda
- **WHEN** um gateway é reiniciado
- **THEN** as configurações e gravações permanecem íntegras na persistência externa
- **AND** o roteamento pelo Traefik direciona a um nó saudável
