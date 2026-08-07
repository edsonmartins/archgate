# ADR-014 — ArchGuard (fork Casdoor) substitui o Kanidm como IdP

- **Status:** Aceito
- **Data:** 2026-08-02
- **Relacionado:** [CONSTITUTION](../CONSTITUTION.md) §2.4, §4.4 · [ADR-005](./ADR-005-nome-do-produto-archgate.md) (ArchGuard = módulo de identidade) · [ADR-007A](./ADR-007A-oauth2-proxy-guacamole-sso.md) · [ADR-009](./ADR-009-control-plane-admin-console.md) Manager
- **Repositório do IdP:** `../archguard` (fork do Casdoor)
- **Runbook:** [virada-kanidm-archguard.md](../documentos/runbooks/virada-kanidm-archguard.md)
- **Smoke:** `deploy/validation/smoke-archguard-cutover.sh`

## Contexto

O ADR-005 definiu o **ArchGuard** como o módulo de identidade dentro do ArchGate. Na Fase 1 esse módulo foi materializado como **Kanidm** operado atrás do console.

O ArchGuard passou a ser um **produto próprio**, construído como fork do Casdoor, com capacidades que o Kanidm não oferece e que o ArchGate precisa: identidade global com `membership` por tenant e isolamento em duas barreiras (repositório com escopo + RLS), trilha de auditoria imutável encadeada, MFA com step-up por nível de garantia, delegação e break-glass, e um plano de controle próprio em `/api/v1`.

Manter dois IdPs — Kanidm para o ArchGate, ArchGuard para o resto — significaria duas fontes de identidade, dois offboardings e auditoria que não correlaciona. É exatamente o que o produto existe para eliminar.

## Decisão

**O ArchGate autentica exclusivamente contra o ArchGuard.** O Kanidm sai de cena.

A compatibilidade seletiva por `ARCHGATE_IDP` existiu apenas durante a virada. Depois do
cutover ela é removida: não há fallback, segundo issuer ou modo de produção suportado com
Kanidm.

### O que muda concretamente

| Aspecto | Kanidm | ArchGuard |
|---|---|---|
| Issuer | um por cliente (`…/oauth2/openid/<client>`) | um por instalação |
| Descoberta | `<issuer>/.well-known/openid-configuration` | `<raiz>/.well-known/openid-configuration` |
| `userinfo` | `<issuer>/userinfo` | `/api/userinfo` |
| `aud` | id do cliente | **clientId** da aplicação (hex), não o nome |
| Grupo no claim | `nome@domínio` | `<org>/<nome>` |
| Chaves | ES256 | RS256 com `kid` |
| Administração | REST `/v1/person`, `/v1/group` | `/api/add-group`, `/api/update-user` |
| Desativar pessoa | `account_expire` no passado | `isForbidden` |
| Credencial de máquina | token de service account opaco | bearer curto via `client_credentials` |

### Contenção do acoplamento

Nenhum consumidor conhece o IdP. Três costuras absorvem a diferença:

1. **Descoberta** (`archguard-console/src/server/idp/discovery.ts`, `clients/archgate-connect/internal/oidc/pkce.go`) — só a URL de descoberta muda de forma; issuer, JWKS, userinfo e token vêm do documento.
2. **Administração** (`archguard-console/src/server/idp/`) — porto `IdentityAdmin` com um adapter por IdP.
3. **Normalização de grupos** (`archguard-console/src/server/idp/groups.ts`) — reduz as duas formas ao nome nu, tolerando sessões mistas durante a migração.

Warpgate e OpenBao não têm costura: comparam strings de grupo por igualdade exata, então recebem o valor já qualificado na configuração de deploy.

## Consequências

### Positivas

- Uma identidade, um offboarding, uma trilha (CONSTITUTION §2.4).
- O ArchGate herda MFA/step-up, delegação e break-glass sem implementá-los.
- Multi-tenancy do ArchGuard (`membership`) substitui a convenção de grupos `tenant_*` quando o pacote 002 for consumido.

### Negativas e residuais

- **Revogação não propaga enquanto os endpoints OIDC v1 não forem montados.** O contrato de claims v1 (`org`, `mid`, `acr`, `sid`, `pcid`), a rotação de refresh com detecção de reuso e o back-channel logout existem no ArchGuard como domínio e testes de conformidade, mas os handlers `internal/http/oidc_*.go` **não estão montados** — quem serve OAuth é o Casdoor legado. Consequência: desabilitar a pessoa bloqueia o próximo login, mas um access token vivo continua válido até expirar.
  **O TTL do access é o limite de revogação.** Com 1h, a janela é ≤ 1h. Montar os endpoints v1 é o que remove esse residual, e é pacote próprio no ArchGuard.
  Compensação atual: o offboarding do Manager também chama a orquestração e o Warpgate, e revoga os leases do OpenBao — o residual fica escopado à sessão OIDC.
- **`tokenFormat` exige `JWT-Custom`.** O formato `JWT` serializa o objeto `User` inteiro e `refineUser()` limpa apenas a senha: `totpSecret`, `recoveryCodes`, `passwordSalt` e `passwordType` sobrevivem no token — que trafega para Warpgate, Guacamole e OpenBao. Usar `JWT-Custom` com campos mínimos não é otimização, é requisito.
- Depender de um fork significa herdar sua superfície legada; o contrato de claims agnóstico do ArchGuard é o que mantém contido o custo de uma eventual troca.
- Durante a migração convivem dois formatos de grupo. A normalização é tolerante por desenho, não por acidente.

## Alternativas descartadas

- **Manter o Kanidm.** Duas fontes de identidade contradizem o valor central do produto.
- **Federar Kanidm ← ArchGuard.** Adiciona um salto e mantém dois lugares para revogar; o pacote 009 do ArchGuard já cobre federação de entrada com IdP de cliente, que é outro problema.
- **Esperar os endpoints v1.** Bloquearia a homologação por um trabalho cujo raio de alcance é um IdP com inquilino em produção. Vira residual explícito, não pré-requisito.

## Aceite

O smoke `deploy/validation/smoke-archguard-cutover.sh` valida as premissas que sustentam três configurações (prefixo do grupo, `aud`, formato do token) e o login no cofre. Falha nele bloqueia a virada do staging.
