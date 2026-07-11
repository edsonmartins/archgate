# Spec Delta — unified-ui

## ADDED Requirements

### Requirement: Sessão Remota Embutida na UnifiedUI
A UnifiedUI SHALL embutir sessões de RDP/SSH dentro do próprio console usando `guacamole-common-js`, com a identidade visual da IntegrAllTech.

#### Scenario: RDP dentro da UnifiedUI
- **WHEN** um desenvolvedor abre uma conexão RDP autorizada
- **THEN** o desktop remoto é renderizado dentro da UnifiedUI via túnel WebSocket até o guacd
- **AND** o desenvolvedor não precisa de nenhuma UI de terceiros

### Requirement: Chrome de Sessão
A UnifiedUI SHALL prover o chrome de sessão: barra de conexão, clipboard, redimensionamento, indicador de gravação e reconexão.

#### Scenario: Indicador de gravação visível
- **WHEN** uma sessão está sendo gravada
- **THEN** a UnifiedUI exibe o indicador de gravação ao desenvolvedor

### Requirement: Token Fora do Browser na Sessão
A UnifiedUI SHALL injetar o token OIDC no handshake do túnel sem expor tokens administrativos ao browser.

#### Scenario: Handshake sem vazar token administrativo
- **WHEN** o componente de sessão estabelece o túnel
- **THEN** apenas o token de sessão do usuário é usado no handshake
- **AND** nenhum token administrativo trafega para o browser
