# Spec Delta — gateway-authentication

## MODIFIED Requirements

### Requirement: Warpgate Autentica via OIDC
O Warpgate SHALL autenticar usuários via OIDC contra o Kanidm, sem autenticação local por senha, e SHALL obter a credencial do alvo como **credencial efêmera do OpenBao** em vez de deter credencial de longa vida.

#### Scenario: SSO no Warpgate com certificado efêmero
- **WHEN** um desenvolvedor autenticado no Kanidm conecta a um target SSH via Warpgate
- **THEN** o Warpgate valida a identidade via OIDC e solicita ao OpenBao um certificado SSH de curta duração
- **AND** injeta o certificado e encaminha ao alvo, sem expor credencial ao desenvolvedor
- **AND** nenhuma credencial de longa vida do alvo reside no Warpgate

#### Scenario: Acesso a banco via credencial dinâmica
- **WHEN** um desenvolvedor conecta a um target PostgreSQL via Warpgate
- **THEN** o Warpgate usa uma credencial dinâmica emitida pelo OpenBao, com TTL
- **AND** a credencial é revogada ao fim do lease

#### Scenario: Autenticação local desabilitada
- **WHEN** alguém tenta autenticar no Warpgate por senha local
- **THEN** a tentativa é rejeitada
