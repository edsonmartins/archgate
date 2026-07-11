# Spec Delta — access-console

## ADDED Requirements

### Requirement: Login do Operador via OIDC
O console (ArchGuard) SHALL autenticar operadores via OIDC contra o Kanidm.

#### Scenario: Operador autentica no console
- **WHEN** um operador acessa o console
- **THEN** é redirecionado ao Kanidm e autentica via OIDC
- **AND** ao retornar, vê apenas os recursos permitidos ao seu papel e tenant

### Requirement: Tokens Sensíveis Fora do Browser
O console SHALL manter tokens administrativos server-side, expondo ao browser apenas o proxy do próprio console.

#### Scenario: Browser não recebe token administrativo
- **WHEN** o operador executa uma ação administrativa pelo console
- **THEN** a chamada à API administrativa ocorre server-side via proxy com validação de path
- **AND** nenhum token de service account trafega para o browser

### Requirement: Administração Escopada por Tenant
O console SHALL restringir o Tenant Admin à gestão de usuários e targets do seu próprio tenant.

#### Scenario: Tenant Admin gerencia apenas seu tenant
- **WHEN** um Tenant Admin do tenant A gerencia usuários/targets
- **THEN** apenas recursos do tenant A são listados e editáveis

### Requirement: Lista de Conexões Autorizadas
O console SHALL apresentar a cada operador somente as conexões que ele está autorizado a usar.

#### Scenario: Operador vê apenas o autorizado
- **WHEN** um operador abre a lista de conexões
- **THEN** vê somente os targets permitidos ao seu papel e tenant

### Requirement: Operações Base por API
O console SHALL expor por API as operações de provisionar/desabilitar usuário e conceder/revogar acesso, para orquestração pelo Mentors Axis.

#### Scenario: Revogação disparada via API
- **WHEN** o Mentors Axis chama a operação de desabilitar um usuário
- **THEN** o console propaga a desativação da identidade no Kanidm
- **AND** o acesso do usuário aos gateways é revogado
