# Proposal — Add Identity Axis (Fase 1)

## Why

A plataforma de acesso privilegiado precisa de um alicerce: **identidade central**. Antes de gateways injetarem credenciais efêmeras (Fase 2) ou de a malha de rede alcançar clientes (Fase 3), todo acesso precisa derivar de uma identidade autenticada, autorizada e revogável em um único ponto.

Hoje os desenvolvedores detêm credenciais dos alvos diretamente, o que torna o offboarding caro (rotacionar tudo, em todos os clientes) e a auditoria fraca. Esta mudança estabelece o **Kanidm como provedor OIDC central** (operado pelo ArchGuard) e faz os dois gateways (Warpgate e Guacamole) confiarem nele.

**Ganho de negócio já nesta fase:** com os gateways mediando o acesso e os desenvolvedores autenticando via SSO, o dev **deixa de possuir** as credenciais dos alvos — quem as detém é o gateway. Portanto, quando um dev sai, **não há senha de cliente para rotacionar**: basta desabilitar a identidade no Kanidm e o SSO cai em toda a stack. A propriedade de *certificado efêmero* (Fase 2) é defesa em profundidade adicional, mas o núcleo da dor de offboarding já é resolvido aqui.

## What Changes

- **Kanidm como IdP OIDC central**, com modelagem de tenants (um por cliente), grupos e papéis RBAC.
- **Service accounts** para identidades não-humanas (base para o caso agêntico da Fase 5).
- **Warpgate autentica via OIDC** contra o Kanidm (sem senhas locais), com gravação de sessão habilitada.
- **Guacamole autentica via extensão OIDC** contra o Kanidm, com gravação de sessão gráfica.
- **ArchGuard como console operador**, mantendo o padrão de tokens fora do browser (proxy server-side).
- **Provisionamento/deprovisionamento por API**, base para a orquestração pelo Mentors Axis.

## Impact

- **Novas capabilities:** `identity`, `gateway-authentication`, `access-console`.
- **Componentes:** Kanidm, Warpgate, Guacamole (guacd + webapp), ArchGuard.
- **Fora de escopo desta fase:** emissão de credenciais efêmeras via OpenBao (Fase 2); malha NetBird (Fase 3); UnifiedUI React com `guacamole-common-js` (Fase 4); OpenSRE/agêntico (Fase 5). Nesta fase, o Warpgate detém as credenciais dos alvos (o dev nunca as vê); a substituição por certificados efêmeros vem na Fase 2.
- **Dependências:** PostgreSQL externo para persistência de Warpgate e Guacamole (não usar SQLite default do Warpgate).
