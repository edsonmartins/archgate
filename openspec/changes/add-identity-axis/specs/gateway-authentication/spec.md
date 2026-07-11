# Spec Delta — gateway-authentication

## ADDED Requirements

### Requirement: Warpgate Autentica via OIDC
O Warpgate SHALL autenticar usuários via OIDC contra o Kanidm, sem autenticação local por senha.

#### Scenario: SSO no Warpgate
- **WHEN** um desenvolvedor autenticado no Kanidm conecta ao Warpgate
- **THEN** o Warpgate valida a identidade via OIDC e concede acesso conforme o RBAC de targets
- **AND** a credencial do alvo é detida/injetada pelo Warpgate, nunca exposta ao desenvolvedor

#### Scenario: Autenticação local desabilitada
- **WHEN** alguém tenta autenticar no Warpgate por senha local
- **THEN** a tentativa é rejeitada

### Requirement: Guacamole Autentica via OIDC
O Guacamole SHALL autenticar usuários via extensão OIDC contra o Kanidm.

#### Scenario: SSO no Guacamole para RDP
- **WHEN** um desenvolvedor autenticado no Kanidm abre uma conexão RDP no Guacamole
- **THEN** o Guacamole valida a identidade via OIDC e injeta a credencial do alvo
- **AND** o desenvolvedor não vê a credencial do alvo

### Requirement: Revogação de Acesso por Identidade
Desabilitar uma identidade no Kanidm SHALL revogar o acesso do principal em ambos os gateways.

#### Scenario: Offboarding derruba SSO nos gateways
- **WHEN** a identidade de um desenvolvedor é desabilitada no Kanidm
- **THEN** ele não consegue mais autenticar no Warpgate nem no Guacamole
- **AND** nenhuma senha de cliente precisa ser rotacionada, pois o desenvolvedor nunca deteve a credencial do alvo

### Requirement: Gravação de Sessão
Ambos os gateways SHALL gravar as sessões privilegiadas para replay e auditoria.

#### Scenario: Sessão SSH gravada
- **WHEN** um desenvolvedor conclui uma sessão SSH via Warpgate
- **THEN** a sessão fica disponível para replay na auditoria

#### Scenario: Sessão RDP gravada
- **WHEN** um desenvolvedor conclui uma sessão RDP via Guacamole
- **THEN** a sessão gráfica fica disponível para replay na auditoria
