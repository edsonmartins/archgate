# Spec Delta — orchestration

## ADDED Requirements

### Requirement: Provisionamento por API
O Mentors Axis SHALL provisionar usuários e conceder acessos por API, aplicando identidade no Kanidm, targets no gateway e policies no OpenBao.

#### Scenario: Onboarding automatizado
- **WHEN** um novo desenvolvedor é adicionado no Mentors Axis com um perfil e tenant
- **THEN** a identidade é criada no Kanidm com o RBAC correto
- **AND** os acessos autorizados são configurados nos gateways e no OpenBao

### Requirement: Offboarding Automatizado
O Mentors Axis SHALL revogar todo o acesso de um principal em uma única operação, sem rotação de senha.

#### Scenario: Revogação em um clique
- **WHEN** um desenvolvedor é desligado no Mentors Axis
- **THEN** a identidade é desabilitada no Kanidm, os leases são invalidados no OpenBao e os roles removidos no gateway
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
