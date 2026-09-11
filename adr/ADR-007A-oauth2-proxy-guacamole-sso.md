# ADR-007A — Adendo: oauth2-proxy (Code+PKCE) na borda do Guacamole

- **Status:** Aceito (caminho intermediário até Guacamole 1.7 Code+PKCE ou UnifiedUI)
- **Data:** julho de 2026
- **Pai:** [ADR-007](ADR-007-guacamole-oidc-implicit-vs-archguard.md)
- **Relacionado:** ADR-008 (Parte A browser); task identity-axis 4.2; OpenSpec operator-client-access

## Contexto

ADR-007 bloqueia a extensão OpenID **stock** do Guacamole 1.6 (implicit) contra archguard.  
O time remoto precisa de **SSO archguard para alcançar a UI** do Guacamole sem violar CONSTITUTION §4.4.

## Decisão

1. Colocar **oauth2-proxy** (OIDC Authorization Code + PKCE) **na frente** de `guac.archgate.com.br`.
2. archguard client `guacamole` (já existente, confidential) como IdP do proxy.
3. Guacamole atrás do proxy com **HTTP header auth** (`X-Forwarded-User`) + JDBC para conexões.
4. Users Guacamole **1:1** com `preferred_username` archguard (script `provision-archguard-users.sh`).
5. Guacamole **não** exposto por Traefik diretamente (somente via oauth2-proxy) — headers de identidade só do hop proxy.
6. Remediações longas: Guacamole ≥1.7 OIDC nativo e/ou UnifiedUI (sem dual stack).

## Controles obrigatórios (segurança)

| # | Controle |
|---|----------|
| C1 | Fail-closed: sem rota Traefik pública direta ao container Guacamole |
| C2 | `allowed_groups` (ou equivalente) = operadores ArchGate (`archguard_users` no mínimo) |
| C3 | Cookie Secure + secret forte; redirect URI allowlist no archguard |
| C4 | Headers de identidade **somente** do oauth2-proxy; Guacamole sem rota pública (C1) |
| C5 | Header-auth + users 1:1; break-glass `guacadmin` só cofre/bootstrap |
| C6 | Offboarding: disable archguard impede portão; opcional desabilitar user Guac espelho |
| C7 | `preferred_username` archguard = username Guacamole (sem SPN no header) |

## Escopo honesto

| É | Não é |
|---|--------|
| SSO archguard Code+PKCE na borda | OIDC nativo da extensão openid stock |
| Identidade Guac = username archguard (header) | Isolamento multi-tenant Guac por claim automático (perms JDBC) |
| Um login archguard → sessão Guac (happy path) | Substitui UnifiedUI / catálogo único |

## Implementação

- Deploy: `deploy/guacamole/oauth2-proxy-deploy.sh`
- Sync users: `deploy/guacamole/provision-archguard-users.sh` (membros de `archguard_users` → JDBC; `DRY_RUN=1` suportado)
- Validação: `deploy/validation/guacamole-sso-proxy-e2e.sh`

## Consequências

**+** Operadores remotos: archguard → Guacamole com mesmo username (header-auth).  
**−** Provisionamento de user Guac deve acompanhar onboarding archguard (script/API).  
**−** Superfície oauth2-proxy a manter (versões/CVEs).
