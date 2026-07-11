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
