# Spec Delta — identity

## ADDED Requirements

### Requirement: Central OIDC Identity Provider
O sistema SHALL usar o Kanidm como provedor de identidade OIDC central para todos os componentes da plataforma.

#### Scenario: Emissão de token para principal autenticado
- **WHEN** um principal (humano ou service account) autentica com credenciais válidas
- **THEN** o Kanidm emite um token OIDC via fluxo Authorization Code + PKCE
- **AND** o token carrega os claims de grupo/tenant do principal

#### Scenario: Fluxo implícito rejeitado
- **WHEN** um client OIDC tenta usar fluxo implícito
- **THEN** a requisição é rejeitada

### Requirement: Modelagem de Tenants
O sistema SHALL modelar cada cliente da IntegrAllTech como um tenant isolado, refletido em grupos/escopos no Kanidm.

#### Scenario: Claim de tenant no token
- **WHEN** um usuário do tenant "Rio Quality" autentica
- **THEN** o token emitido identifica o tenant do usuário
- **AND** esse claim é utilizável para decisão de RBAC pelos gateways e pelo console

### Requirement: Papéis RBAC
O sistema SHALL definir e aplicar os papéis Super Admin, Tenant Admin, Operador, Service Desk e Viewer.

#### Scenario: Operador enxerga apenas o autorizado
- **WHEN** um Operador autentica
- **THEN** o sistema expõe somente as conexões/targets autorizados para seu papel e tenant

#### Scenario: Tenant Admin restrito ao seu tenant
- **WHEN** um Tenant Admin do tenant A tenta administrar recursos do tenant B
- **THEN** a operação é negada

### Requirement: Identidades Não-Humanas (Service Accounts)
O sistema SHALL suportar service accounts como identidades não-humanas com escopo próprio.

#### Scenario: Autenticação de service account
- **WHEN** uma service account autentica com sua credencial
- **THEN** o Kanidm emite token com o escopo restrito daquela conta
- **AND** o principal é distinguível de um usuário humano na auditoria

### Requirement: Provisionamento e Deprovisionamento por API
O sistema SHALL permitir criar, habilitar e desabilitar identidades via API.

#### Scenario: Desabilitar identidade revoga acesso
- **WHEN** uma identidade é desabilitada no Kanidm via API
- **THEN** novas autenticações daquele principal falham em todos os componentes que confiam no Kanidm
