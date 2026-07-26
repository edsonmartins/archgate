# Spec Delta — org-credential-broker

## ADDED Requirements

### Requirement: Inventário de contas organizacionais
O sistema SHALL manter um inventário de contas da IntegrAllTech (cloud, lojas, produtos, vendors) no control plane, com metadados (nome, URL, categoria, criticidade, owner) **sem** expor o valor do segredo nas listagens.

#### Scenario: Listar contas autorizadas
- **WHEN** um principal autenticado com `org_accounts:read` solicita o catálogo
- **THEN** o sistema retorna apenas contas cujo RBAC e/ou `owner_group` o autorizam
- **AND** a resposta **não** inclui password, api_key ou totp_seed

#### Scenario: Conta P0 identificada
- **WHEN** uma conta tem `criticality = P0`
- **THEN** o metadado `requires_dual_control` é true por padrão (salvo waiver explícito de admin)

### Requirement: Segredo somente no OpenBao
O material secreto de uma conta org SHALL residir no OpenBao sob paths `secret/data/org/…` referenciados por `secret_ref`. O browser SHALL NOT receber tokens de serviço OpenBao.

#### Scenario: Write admin de secret
- **WHEN** um admin com `org_accounts:admin` associa ou rotaciona o secret de uma conta
- **THEN** o console grava/atualiza o KV no OpenBao via proxy server-side
- **AND** o valor não é logado em plain text no activity log

### Requirement: Checkout com motivo e TTL
O sistema SHALL exigir motivo e TTL para qualquer reveal de secret de conta org.

#### Scenario: Checkout bem-sucedido (não P0 ou já aprovado)
- **WHEN** um principal com `org_accounts:checkout` solicita checkout com `reason` não vazio e `ttl_seconds` dentro do limite de política
- **THEN** o sistema registra um `OrgCheckout` ativo
- **AND** devolve o secret **uma vez** na resposta da API
- **AND** registra evento de auditoria com principal, account_id, reason, expires_at

#### Scenario: Checkout sem motivo rejeitado
- **WHEN** a solicitação omite `reason` ou usa TTL acima do máximo permitido
- **THEN** o sistema responde 400 e não lê o OpenBao

### Requirement: Dual-control para P0
Contas P0 (ou com `requires_dual_control`) SHALL exigir aprovação de um segundo principal com `org_accounts:approve` antes do reveal.

#### Scenario: Checkout P0 pendente
- **WHEN** um solicitante pede checkout de conta P0
- **THEN** o status fica `pending` e o secret **não** é devolvido
- **AND** um aprovador distinto pode aprovar ou negar

#### Scenario: Auto-aprovação proibida
- **WHEN** o solicitante tenta aprovar o próprio checkout P0
- **THEN** o sistema rejeita com 403

### Requirement: Offboarding corta acesso
Revogar ou desabilitar o principal no Kanidm SHALL impedir novos checkouts e o acesso à UI do módulo.

#### Scenario: Usuário desabilitado
- **WHEN** a sessão OIDC do principal deixa de ser válida ou o usuário está desabilitado
- **THEN** `checkout` e `approve` retornam 401/403
- **AND** listagens autenticadas falham da mesma forma que o restante do Manager

### Requirement: Separação de domínios
O módulo de contas org SHALL ser visual e autorizacionalmente distinto do catálogo de sites/targets de cliente e do ArchGate Connect.

#### Scenario: Connect não lista contas org no MVP
- **WHEN** um operador usa ArchGate Connect
- **THEN** o catálogo de conexões de bastion **não** inclui `OrgAccount` como target de sessão embutida
- **AND** nenhum secret org é persistido em localStorage/keychain do Connect

### Requirement: Preferência por redução de senha compartilhada
O desenho SHALL permitir evolução para API keys e OIDC sem quebrar o inventário.

#### Scenario: Conta auth_kind api_key
- **WHEN** `auth_kind = api_key`
- **THEN** o checkout revela o material de API key (não necessariamente “password”)
- **AND** o metadado permanece no mesmo inventário

### Requirement: Auditoria completa
Toda operação de create/update account, checkout, approve, deny, checkin e falha de OpenBao SHALL gerar registro de auditoria consultável por admin.

#### Scenario: Trilha de reveal
- **WHEN** um admin consulta a auditoria de uma conta
- **THEN** constam os checkouts com principal, reason, timestamps e status
