# ADR-007 — Guacamole OIDC stock (implicit) vs Kanidm / CONSTITUTION

- **Status:** Aceito (limitação Fase 1; remediação Fase 4)
- **Data:** julho de 2026
- **Relacionado:** CONSTITUTION §4.4 (OIDC Authorization Code + PKCE); `add-identity-axis` 4.2; [ADR-008](ADR-008-cliente-operador-hibrido-multi-os.md) (RDP browser vs desktop; 4.2 não bloqueia personas SSH/DB)

## Contexto

A extensão OpenID Connect embutida no Apache Guacamole 1.6.0 implementa o **OIDC Implicit Flow** (`response_type=id_token`). O Kanidm 1.10, configurado conforme a constituição ArchGate, expõe apenas:

- `grant_types_supported`: `authorization_code`, token-exchange  
- `response_types_supported`: `code`

Além disso, a CONSTITUTION §4.4 proíbe fluxos implícitos.

## Decisão

1. **Fase 1:** Guacamole autentica via **PostgreSQL** (auth JDBC) com UI stock; conexões de lab (SSH browser) com **gravação** habilitada; credenciais de alvo só no gateway.
2. **Não** habilitar a extensão OpenID stock contra Kanidm nesta fase (seria inviável e violaria a constituição).
3. **Fase 4 (UnifiedUI / orquestração):** SSO browser unificado via React + fluxo Authorization Code + PKCE no console ArchGate, embutindo sessão com `guacamole-common-js` (sem herdar o chrome AngularJS nem o OIDC implícito).
4. Alternativa intermediária (se necessário antes da Fase 4): **oauth2-proxy** (ou similar) com Authorization Code + PKCE na borda Traefik, terminando SSO antes do Guacamole.  
   → **Implementado como ADR-007A** (`deploy/guacamole/oauth2-proxy-deploy.sh`, staging 2026-07-10).

## Consequências

**Positivas:** conformidade com Kanidm e CONSTITUTION; Guacamole operacional para RDP/SSH browser e gravação.

**Negativas:** operadores usam login local Guacamole (`guacadmin`) até UnifiedUI; offboarding no Guacamole não é automático via Kanidm (mitigar com provisionamento manual/API até Fase 4).

## Referências

- https://guacamole.apache.org/doc/gug/openid-auth.html  
- Kanidm OIDC discovery: `https://id.archgate.com.br/oauth2/openid/guacamole/.well-known/openid-configuration`
