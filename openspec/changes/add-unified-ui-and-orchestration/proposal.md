# Proposal — Add Unified UI and Orchestration (Fase 4)

## Why

Até aqui, o acesso funciona, mas a experiência do dev ainda passa por UIs de ferramentas distintas, e o provisionamento é semi-manual. Esta fase entrega o **single pane of glass** — uma UnifiedUI própria da IntegrAllTech — e automatiza onboarding/offboarding via **orquestração pelo Mentors Axis**.

A UnifiedUI embute a sessão de RDP/SSH dentro do console (via `guacamole-common-js`), com a identidade visual da IntegrAllTech; e o Mentors Axis passa a ser a fonte de verdade que provisiona e revoga por API/IaC.

## What Changes

- **UnifiedUI React** embutindo sessão remota via `guacamole-common-js` (túnel WebSocket até o guacd), com o *chrome* de sessão (barra de conexão, clipboard, resize, indicador de gravação, reconexão).
- Tokens sensíveis permanecem fora do browser (mantém o padrão do console).
- **Orquestração via Mentors Axis:** contratos de API para provisionar/revogar, com Terraform onde disponível (Warpgate) e API para Kanidm/OpenBao/Guacamole/NetBird.
- **Onboarding/offboarding automatizados** ponta a ponta.
- **Sincronização de tenants** do registro de clientes do Mentors Axis.

## Impact

- **Novas capabilities:** `unified-ui`, `orchestration`.
- **Capability modificada:** `access-console` (evolui do rebrand stock do Guacamole para a UnifiedUI).
- **Componentes:** UnifiedUI (React/TS), Mentors Axis, Terraform, APIs de todos os componentes.
- **Depende de:** Fases 1–3.
- **Nota de esforço:** o `guacamole-common-js` é projeto frontend de verdade (não tema); ver design.
- **Fora de escopo:** agêntico e HA (Fase 5).
