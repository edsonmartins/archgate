# Spec Delta — agentic-access

## ADDED Requirements

### Requirement: Agente como Principal Não-Confiável
O sistema SHALL tratar um agente de IA como um principal (service account) não-confiável por padrão, sujeito à mesma autenticação, autorização, credencial efêmera e gravação dos humanos.

#### Scenario: Agente autentica como service account
- **WHEN** o OpenSRE inicia uma operação
- **THEN** ele autentica como service account no Kanidm com escopo mínimo
- **AND** recebe credencial efêmera via OpenBao, escopada ao incidente/host

### Requirement: Política Imposta no Gateway
O sistema SHALL impor allow-list de comandos, escopo por host, TTL curtíssimo e rate limit no gateway, sem delegar a decisão ao raciocínio do agente.

#### Scenario: Prompt injection não escala privilégio
- **WHEN** o agente processa um log contendo instrução maliciosa
- **THEN** qualquer comando fora da allow-list ou do escopo é bloqueado pelo gateway
- **AND** o privilégio do agente não é ampliado

### Requirement: Autenticação do Plano de Controle Agêntico
A API de controle de agentes SHALL autenticar toda chamada e SHALL falhar fechada quando nenhuma credencial estiver configurada. A identidade do agente SHALL derivar da credencial apresentada, nunca de um campo do corpo da requisição. A API SHALL NOT ser exposta na borda pública.

#### Scenario: Agente não pode se declarar
- **WHEN** uma requisição informa `agent_id` divergente da credencial apresentada
- **THEN** a requisição é rejeitada com 403
- **AND** a tentativa é registrada na auditoria

#### Scenario: Chamada anônima é rejeitada
- **WHEN** uma requisição chega sem credencial
- **THEN** a resposta é 401 e nenhuma ação é enfileirada

### Requirement: Separação de Credenciais entre Agente e Aprovador
Aprovação HITL e kill-switch SHALL exigir uma credencial distinta da usada pelo agente, de modo que a posse da credencial do agente não permita aprovar as próprias ações nem desligar o kill-switch.

#### Scenario: Agente não aprova a própria ação
- **WHEN** um chamador autenticado com a credencial do agente chama `POST /agentic/v1/approvals/{id}/approve`
- **THEN** a requisição é rejeitada com 403
- **AND** a ação permanece pendente

#### Scenario: Aprovador registra identidade
- **WHEN** um chamador autenticado com a credencial de aprovador aprova a ação
- **THEN** a auditoria registra o aprovador declarado junto da ação e da service account do agente

### Requirement: HITL para Ações Mutantes
O sistema SHALL permitir leitura ampla de forma automática, mas SHALL exigir aprovação humana em tempo real para qualquer ação mutante ou destrutiva.

#### Scenario: Diagnóstico automático, write aprovado
- **WHEN** o agente executa uma ação de leitura
- **THEN** ela ocorre sem aprovação
- **WHEN** o agente tenta uma ação mutante
- **THEN** a ação fica pendente de aprovação humana antes de executar

### Requirement: Responsabilização On-Behalf-Of
O sistema SHALL amarrar cada ação do agente à service account e ao humano que a autorizou.

#### Scenario: Cadeia de responsabilização na auditoria
- **WHEN** o agente executa uma ação aprovada
- **THEN** a auditoria registra a service account e o humano autorizador

### Requirement: Kill-Switch do Agente
O sistema SHALL interromper um agente revogando sua service account no Kanidm, com efeito imediato.

#### Scenario: Agente descarrilado é interrompido
- **WHEN** a service account do agente é revogada no Kanidm
- **THEN** o OpenBao não emite novas credenciais para ele
- **AND** as credenciais ativas expiram em minutos

### Requirement: Inferência Local para Dado de Cliente
O sistema SHALL executar a inferência do agente localmente quando houver dado de produção de cliente, sem enviá-lo a APIs de terceiros.

#### Scenario: Dado de produção não sai da infraestrutura
- **WHEN** o agente opera sobre dados de produção de um cliente
- **THEN** a inferência ocorre localmente (vLLM na infraestrutura da IntegrAllTech)
- **AND** nenhum dado de produção é enviado a APIs de LLM de terceiros
