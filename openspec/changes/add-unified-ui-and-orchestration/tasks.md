# Tasks — Add Unified UI and Orchestration (Fase 4)

## 1. Componente de sessão (guacamole-common-js)
- [x] 1.1 Esqueleto React/TS com painel de sessão (chrome) — `frontend/unified-ui` 2026-07-17
- [x] 1.2 `Guacamole.Client` + WebSocketTunnel no `GuacamoleDisplay` (token BFF)
- [x] 1.3 Ciclo de vida da sessão (connect/disconnect + error states)
- [ ] 1.4 Handshake lab com BFF real (`POST /api/unified/v1/sessions`)
- [x] 1.5 Chrome de sessão (barra connect/disconnect) — clipboard/resize/recording TBD
- [x] 1.6 Launch Warpgate desktop (SSH/PG snippets + deep-link) — W4-UI07 2026-07-17

## 2. Integração na UnifiedUI
- [x] 2.1 App UnifiedUI separado (ADR-006); visual dark IntegrAllTech scaffold
- [x] 2.2 Tela "minhas conexões" com filtro tenant + client BFF (fallback mock)
- [x] 2.3 Princípio tokens admin fora do browser documentado no scaffold
- [x] 2.4 Scaffold OIDC Code+PKCE + callback route (enable com VITE_OIDC_ENABLED)
- [ ] 2.5 Aposentar a UI stock do Guacamole do fluxo do dev (lab path)
- [ ] 2.6 Client Kanidm real + BFF cookie session em lab

## 3. Contratos de orquestração (Mentors Axis)
- [x] 3.1 `provisionar_usuario` API mock multi-adapter — `services/orchestration` 2026-07-17
- [x] 3.2 `conceder_acesso` API mock (WG/OpenBao)
- [x] 3.3 `revogar_tudo` one-shot mock + testes de idempotência
- [x] 3.4 `sincronizar_tenants()` — lab CLI/UI + endpoint stub API
- [ ] 3.5 Terraform provider do Warpgate como fonte de verdade de targets/roles
- [x] 3.6 Adapters live HTTP dry-run (Kanidm/WG/Guac/OpenBao) — calibrar paths no lab
- [x] 3.7 Webhook Axis + Idempotency-Key

## 4. Automação de ciclo de vida
- [x] 4.1 Onboarding API mock (provision + grant)
- [x] 4.2 Offboarding API mock one-shot
- [x] 4.3 Idempotência de revoke no mock (re-run ok)
- [ ] 4.4 Reconciliação live estado desejado vs. real

## 5. Validação
- [ ] 5.1 Dev abre RDP/SSH inteiramente dentro da UnifiedUI, sem UI de terceiros
- [ ] 5.2 Onboarding/offboarding disparados pelo Mentors Axis refletem em todos os componentes
- [x] 5.3 Design: nenhum token administrativo no browser (contrato + SPA)
- [x] 5.4 Smoke mock API: `deploy/validation/smoke-orchestration-mock.sh`
