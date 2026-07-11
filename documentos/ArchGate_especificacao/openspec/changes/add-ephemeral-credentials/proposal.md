# Proposal — Add Ephemeral Credentials (Fase 2)

## Why

A Fase 1 já resolve o núcleo do offboarding: como o gateway detém as credenciais dos alvos e o dev só faz SSO, sair da empresa não exige rotacionar senha. Esta fase adiciona **defesa em profundidade**: remove a credencial de longa vida até do próprio gateway, emitindo credenciais **efêmeras** via OpenBao.

Com isso, o comprometimento do gateway deixa de expor chaves permanentes dos alvos, e o modelo de acesso passa a "menor privilégio + menor duração" de ponta a ponta. É o que fecha a promessa técnica da plataforma.

## What Changes

- **OpenBao** como emissor central de credenciais efêmeras (MPL-2.0, Linux Foundation).
- **SSH Secrets Engine (CA):** assina certificados SSH de curta duração; os alvos passam a confiar na CA.
- **Database Secrets Engine:** credenciais dinâmicas de PostgreSQL, criadas sob demanda com TTL e revogadas ao fim.
- **Warpgate** passa a solicitar certificado/credencial efêmera ao OpenBao em vez de deter chave/senha de longa vida.
- **Políticas de TTL e leases** com auditoria de emissão e revogação.

## Impact

- **Nova capability:** `ephemeral-credentials`.
- **Capability modificada:** `gateway-authentication` (Warpgate deixa de guardar credencial de longa vida).
- **Componentes:** OpenBao (HA, unseal), Warpgate, alvos SSH (passam a confiar na CA), PostgreSQL-alvo (usuário administrativo para credenciais dinâmicas).
- **Depende de:** Fase 1 (identidade). **Oracle** fica pendente do ADR-001 (tratado na Fase 3).
- **Fora de escopo:** NetBird (Fase 3), UnifiedUI (Fase 4), agêntico (Fase 5).
