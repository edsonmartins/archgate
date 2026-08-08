# Spec Delta — orchestration

## ADDED Requirements

### Requirement: Autenticação da API de Orquestração
A API de orquestração SHALL rejeitar qualquer chamada não autenticada e SHALL falhar fechada: sem credencial configurada, o serviço não atende nenhuma rota de mutação. A API SHALL NOT ser exposta na borda pública; o alcance é a rede interna do plano de controle.

#### Scenario: Chamada sem credencial é rejeitada
- **WHEN** um cliente chama `POST /orchestration/v1/users/provision` sem credencial válida
- **THEN** a requisição é rejeitada com 401
- **AND** nenhum componente (archguard, Warpgate, Guacamole, OpenBao) é tocado

#### Scenario: Serviço sem credencial configurada não atende
- **WHEN** o serviço sobe sem token de serviço configurado
- **THEN** toda rota de mutação responde 503
- **AND** o evento é registrado como erro de configuração

#### Scenario: Sonda de saúde não exige credencial
- **WHEN** a plataforma consulta `GET /actuator/health`
- **THEN** a resposta é 200 sem credencial
- **AND** nenhum dado sensível é exposto

### Requirement: Webhooks Assinados
Os webhooks recebidos do Mentors Axis SHALL ser autenticados por assinatura HMAC-SHA256 do corpo, comparada em tempo constante, além da credencial de serviço.

#### Scenario: Webhook com assinatura inválida é descartado
- **WHEN** chega um evento em `POST /orchestration/v1/webhooks/axis` com assinatura ausente ou incorreta
- **THEN** a requisição é rejeitada com 401
- **AND** nenhuma operação de ciclo de vida é executada

#### Scenario: Reenvio idempotente continua funcionando
- **WHEN** o Axis reenvia um evento assinado com a mesma `Idempotency-Key`
- **THEN** o resultado anterior é devolvido sem reexecutar a operação

### Requirement: Provisionamento por API
O Mentors Axis SHALL provisionar usuários e conceder acessos por API, aplicando identidade no archguard, targets no gateway e policies no OpenBao.

#### Scenario: Onboarding automatizado
- **WHEN** um novo desenvolvedor é adicionado no Mentors Axis com um perfil e tenant
- **THEN** a identidade é criada no archguard com o RBAC correto
- **AND** os acessos autorizados são configurados nos gateways e no OpenBao

### Requirement: Offboarding Automatizado
O Mentors Axis SHALL revogar todo o acesso de um principal em uma única operação, sem rotação de senha.

#### Scenario: Revogação em um clique
- **WHEN** um desenvolvedor é desligado no Mentors Axis
- **THEN** a identidade é desabilitada no archguard, os leases são invalidados no OpenBao e os roles removidos no gateway
- **AND** nenhuma senha de cliente precisa ser rotacionada

### Requirement: Sincronização de Tenants
O Mentors Axis SHALL ser a fonte de verdade dos tenants, refletindo o registro de clientes na plataforma.

#### Scenario: Novo cliente vira tenant
- **WHEN** um novo cliente é cadastrado no Mentors Axis
- **THEN** o tenant correspondente é refletido na plataforma de acesso

### Requirement: Infraestrutura como Código
O provisionamento SHALL usar IaC (Terraform) onde disponível, com estado versionado e reconciliação.

#### Scenario: Deriva reconciliada
- **WHEN** o estado real diverge do estado desejado declarado em IaC
- **THEN** a reconciliação restaura o estado desejado de forma idempotente
