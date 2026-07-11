# Spec Delta — oracle-credential-proxy

## ADDED Requirements

### Requirement: Emissão de Credencial Oracle via Proxy Java
O sistema SHALL emitir credenciais dinâmicas Oracle por meio de um proxy Java que atende à interface de plugin de banco do OpenBao, usando driver JDBC thin, sem bibliotecas nativas na imagem do OpenBao.

#### Scenario: Credencial Oracle dinâmica emitida
- **WHEN** um principal autenticado solicita acesso a um banco Oracle
- **THEN** o OpenBao, via plugin Go e proxy Java, cria um usuário Oracle temporário com permissões mínimas e TTL
- **AND** a imagem do OpenBao não contém bibliotecas nativas Oracle

#### Scenario: Revogação e expiração no Oracle
- **WHEN** o lease de uma credencial Oracle expira ou é revogado
- **THEN** o proxy remove (ou bloqueia) o usuário correspondente no Oracle

### Requirement: Suporte a TNS/Failover
O proxy SHALL suportar descritores TNS e failover multi-instância via o driver JDBC thin.

#### Scenario: Conexão por descritor TNS
- **WHEN** o ambiente Oracle exige TNS aliasing/failover
- **THEN** o proxy estabelece a conexão pelo descritor configurado sem depender de bibliotecas nativas

### Requirement: Canal Seguro e Privilégio Mínimo
O canal entre plugin Go e proxy Java SHALL usar mTLS, e o proxy SHALL operar com um usuário administrativo Oracle de privilégio mínimo.

#### Scenario: Operação administrativa autenticada
- **WHEN** o plugin Go envia uma operação de criação/remoção de usuário ao proxy
- **THEN** a chamada é autenticada por mTLS
- **AND** o proxy executa usando um usuário Oracle com apenas os privilégios necessários (não DBA)

### Requirement: Rastreabilidade da Emissão
A emissão de credencial Oracle SHALL ser amarrada à identidade Kanidm do solicitante.

#### Scenario: Auditoria da credencial Oracle
- **WHEN** uma credencial Oracle é emitida
- **THEN** a auditoria registra o principal solicitante, o alvo, o TTL e o momento
