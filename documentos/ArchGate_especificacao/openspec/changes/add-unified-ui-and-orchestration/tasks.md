# Tasks — Add Unified UI and Orchestration (Fase 4)

## 1. Componente de sessão (guacamole-common-js)
- [ ] 1.1 Esqueleto React/TS com túnel WebSocket até o guacd
- [ ] 1.2 Instanciar `Guacamole.Client` e renderizar display em `<canvas>`
- [ ] 1.3 Ciclo de vida da sessão (connect, disconnect, erro, reconexão)
- [ ] 1.4 Injeção do token OIDC (archguard) no handshake do túnel
- [ ] 1.5 Chrome de sessão: barra de conexão, clipboard, resize, indicador de gravação

## 2. Integração na UnifiedUI
- [ ] 2.1 Embutir o componente de sessão no console (identidade visual IntegrAllTech)
- [ ] 2.2 Tela "minhas conexões" consumindo o RBAC do tenant
- [ ] 2.3 Garantir tokens sensíveis fora do browser (proxy server-side mantido)
- [ ] 2.4 Aposentar a UI stock do Guacamole do fluxo do dev

## 3. Contratos de orquestração (Mentors Axis)
- [ ] 3.1 `provisionar_usuario(tenant, perfil)` → cria em archguard + aplica RBAC
- [ ] 3.2 `conceder_acesso(usuario, target, ttl)` → target no gateway + policy no OpenBao
- [ ] 3.3 `revogar_tudo(usuario)` → desabilita em archguard + invalida leases no OpenBao
- [ ] 3.4 `sincronizar_tenants()` → reflete o registro de clientes do Mentors Axis
- [ ] 3.5 Terraform provider do Warpgate como fonte de verdade de targets/roles

## 4. Automação de ciclo de vida
- [ ] 4.1 Onboarding automatizado ponta a ponta (um clique/uma chamada)
- [ ] 4.2 Offboarding automatizado ponta a ponta (revoga tudo, sem rotação)
- [ ] 4.3 Idempotência e reconciliação (estado desejado vs. real)

## 5. Validação
- [ ] 5.1 Dev abre RDP/SSH inteiramente dentro da UnifiedUI, sem UI de terceiros
- [ ] 5.2 Onboarding/offboarding disparados pelo Mentors Axis refletem em todos os componentes
- [ ] 5.3 Nenhum token administrativo trafega para o browser
