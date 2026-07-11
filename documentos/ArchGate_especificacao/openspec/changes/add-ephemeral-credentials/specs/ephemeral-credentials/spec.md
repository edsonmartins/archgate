# Spec Delta — ephemeral-credentials

## ADDED Requirements

### Requirement: Emissor Central de Credenciais Efêmeras
O sistema SHALL usar o OpenBao como emissor central de credenciais efêmeras, com auditoria de emissão e revogação.

#### Scenario: Emissão amarrada à identidade
- **WHEN** um principal autenticado solicita acesso a um alvo
- **THEN** o OpenBao emite uma credencial efêmera amarrada à identidade Kanidm do solicitante
- **AND** a emissão é registrada na auditoria (quem, alvo, TTL, momento)

### Requirement: Certificado SSH de Curta Duração
O sistema SHALL conceder acesso SSH via certificado assinado pela CA do OpenBao, com TTL curto, e os alvos SHALL confiar apenas nessa CA.

#### Scenario: Login com certificado efêmero
- **WHEN** um desenvolvedor abre uma sessão SSH via gateway
- **THEN** o OpenBao assina um certificado com TTL de 5–15 minutos para aquele alvo e principal
- **AND** o alvo aceita a conexão por confiar na CA

#### Scenario: Chave estática rejeitada
- **WHEN** uma tentativa de login usa chave estática de longa vida
- **THEN** o alvo rejeita, pois confia apenas na CA

### Requirement: Credencial Dinâmica de Banco
O sistema SHALL conceder acesso a PostgreSQL via credencial dinâmica criada sob demanda com TTL e revogada ao fim do lease.

#### Scenario: Credencial de banco com ciclo de vida
- **WHEN** um desenvolvedor solicita acesso ao PostgreSQL de um alvo
- **THEN** o OpenBao cria um usuário temporário com permissões mínimas e TTL
- **AND** ao expirar o lease, a credencial é revogada automaticamente

### Requirement: Revogação e Expiração
O sistema SHALL suportar revogação imediata de leases e expiração automática por TTL.

#### Scenario: Offboarding sem exposição residual
- **WHEN** a identidade de um principal é desabilitada no Kanidm
- **THEN** o OpenBao não emite novas credenciais para ele
- **AND** quaisquer credenciais ativas expiram sozinhas ao fim do TTL curto
