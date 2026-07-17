# Tasks — Add Unified UI and Orchestration (Fase 4)

## 1. Componente de sessão (guacamole-common-js)
- [x] 1.1 Esqueleto React/TS com painel de sessão (chrome) — `frontend/unified-ui` 2026-07-17
- [ ] 1.2 Instanciar `Guacamole.Client` e renderizar display em `<canvas>`
- [x] 1.3 Ciclo de vida da sessão (connect/disconnect stub states)
- [ ] 1.4 Injeção do token OIDC (Kanidm) no handshake do túnel
- [x] 1.5 Chrome de sessão (barra connect/disconnect) — clipboard/resize/recording TBD

## 2. Integração na UnifiedUI
- [x] 2.1 App UnifiedUI separado (ADR-006); visual dark IntegrAllTech scaffold
- [x] 2.2 Tela "minhas conexões" com filtro tenant mock
- [x] 2.3 Princípio tokens admin fora do browser documentado no scaffold
- [ ] 2.4 Aposentar a UI stock do Guacamole do fluxo do dev

## 3. Contratos de orquestração (Mentors Axis)
- [ ] 3.1 `provisionar_usuario(tenant, perfil)` → cria em Kanidm + aplica RBAC
- [ ] 3.2 `conceder_acesso(usuario, target, ttl)` → target no gateway + policy no OpenBao
- [ ] 3.3 `revogar_tudo(usuario)` → desabilita em Kanidm + invalida leases no OpenBao
- [x] 3.4 `sincronizar_tenants()` — lab CLI/UI existe; contrato API em `orchestration-api-contracts.md`
- [ ] 3.5 Terraform provider do Warpgate como fonte de verdade de targets/roles

## 4. Automação de ciclo de vida
- [ ] 4.1 Onboarding automatizado ponta a ponta (um clique/uma chamada)
- [ ] 4.2 Offboarding automatizado ponta a ponta (revoga tudo, sem rotação)
- [ ] 4.3 Idempotência e reconciliação (estado desejado vs. real)

## 5. Validação
- [ ] 5.1 Dev abre RDP/SSH inteiramente dentro da UnifiedUI, sem UI de terceiros
- [ ] 5.2 Onboarding/offboarding disparados pelo Mentors Axis refletem em todos os componentes
- [ ] 5.3 Nenhum token administrativo trafega para o browser
