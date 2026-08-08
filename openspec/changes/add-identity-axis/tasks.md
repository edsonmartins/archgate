# Tasks — Add Identity Axis (Fase 1)

## 1. Infraestrutura base
- [x] 1.1 Provisionar PostgreSQL externo (schemas separados para Warpgate e Guacamole)
- [x] 1.2 Definir stack Docker Swarm + Traefik (roteamento/TLS de borda) para os serviços da fase
- [x] 1.3 Definir gestão de segredos de bootstrap (fora da plataforma que eles protegem)

## 2. Identidade via ArchGuard (archguard + Console) — repo `archguard`
> Não reimplementar archguard no monorepo ArchGate. Fonte: `/Users/edsonmartins/desenvolvimento/archguard`. Ver `deploy/archguard-integration.md`.
- [x] 2.1 Deploy do ArchGuard no host ArchGate (archguard + TLS em `id.archgate.com.br`; console em `console.archgate.com.br`)
- [x] 2.2 Modelar tenants (um por cliente: Rio Quality, Grupo Marra, ...) como grupos/escopos no archguard do ArchGuard
- [x] 2.3 Garantir papéis RBAC ArchGuard: `archguard_super_admins`, `archguard_tenant_admins`, `archguard_users` (Operador), `archguard_service_desk`, `archguard_viewers`
- [x] 2.4 Garantir service account `archguard-sa` (setup-archguard) + SA de exemplo para agentes (Fase 5)
- [x] 2.5 Registrar OAuth2/OIDC clients no archguard do ArchGuard: `warpgate`, `guacamole`, `archguard-console`
- [x] 2.6 Configurar fluxo Authorization Code + PKCE; desabilitar fluxos implícitos
- [x] 2.7 Validar emissão de token e claims (grupos/tenant no token)

## 3. Warpgate (gateway SSH/HTTPS/K8s/DB)
- [x] 3.1 Subir Warpgate apontando persistência ao PostgreSQL externo (não SQLite)
- [x] 3.2 Configurar SSO provider = archguard (OpenID Connect)
- [x] 3.3 Desabilitar autenticação local por senha para operadores (SSO ativo; senha admin bootstrap pode permanecer)
- [x] 3.4 Habilitar gravação de sessão (live + replay)
- [x] 3.5 Mapear papéis/grupos do archguard para RBAC de targets no Warpgate
- [x] 3.6 Cadastrar 1 target SSH e 1 target PostgreSQL de teste (credencial detida pelo Warpgate)
- [x] 3.7 Validar: dev autentica via SSO e abre sessão sem ver a credencial do alvo

## 4. Guacamole (gateway RDP/VNC/browser)
- [x] 4.1 Subir guacd + webapp Guacamole apontando ao PostgreSQL externo
- [x] 4.2 SSO browser no Guacamole com archguard (Code+PKCE) — **via oauth2-proxy na borda (ADR-007A)** (2026-07-10)
  - Extensão OpenID **stock** (implicit) permanece **não** usada (ADR-007)
  - Deploy: `deploy/guacamole/oauth2-proxy-deploy.sh`
  - E2E: `deploy/validation/guacamole-sso-proxy-e2e.sh` (302 → archguard `response_type=code` + PKCE S256)
  - Guacamole JDBC atrás do portão (dual session documentada)
  - Remediação nativa: Guacamole 1.7+ Code+PKCE ou UnifiedUI (Fase 4)
- [x] 4.3 Habilitar gravação de sessão gráfica
- [x] 4.4 Cadastrar 1 conexão de teste browser (SSH lab via Guacamole; RDP Windows pendente host)
- [x] 4.5 Validar: login gateway + lista de conexões sem expor senha do alvo (SSO Guacamole portão = ADR-007A; JDBC atrás do proxy)

## 5. ArchGuard Console (console operador — produto existente)
> Console = `archguard/archguard-console`. Não reescrever UI na Fase 1; deploy + wiring OIDC + APIs de provisionamento.
- [x] 5.1 Deploy/config do console com login OIDC no archguard do ArchGuard (`id.archgate.com.br`)
- [x] 5.2 Confirmar padrão de token fora do browser (proxy server-side + allowlist de path — já no código)
- [x] 5.3 Tela: Tenant Admin gerencia usuários/grupos do próprio tenant (capacidade ArchGuard; targets de gateway podem ser só leitura nesta fase)
  - RBAC: `archguard_tenant_admins` + membership `tenant_{slug}`; UI stock Identidades/Grupos com perms create/update/members
  - Filtro multi-tenant: `useTenantFilter` força escopo do tenant (não vê outros)
  - Sample user `tenantadmin` (Rio Quality only) no bootstrap
- [x] 5.4 Tela: Operador vê apenas o autorizado (grupos/claims); lista de **conexões de gateway** pode ser via UI stock Warpgate/Guacamole até Fase 4
  - `archguard_users` / `archguard_viewers` → read-only; filtro por `tenant_*` claims
  - Conexões de gateway: UI stock Warpgate/Guacamole (fora do console até Fase 4)
- [x] 5.5 Expor/usar operações base por API archguard (via console/SA): provisionar/desabilitar usuário, conceder/revogar acesso (grupos)
  - Proxy SA allowlist `/v1/person` + `/v1/group`; validado com `deploy/validation/console-rbac-e2e.sh`

## 6. Validação de ponta a ponta
- [x] 6.1 Login único: mesma identidade archguard acessa Warpgate, console e **portão** Guacamole (oauth2-proxy ADR-007A; sessão app Guac ainda JDBC até UnifiedUI/1.7)
- [x] 6.2 Isolamento: usuário do tenant A não enxerga targets do tenant B
- [x] 6.3 **Offboarding:** desabilitar identidade no archguard derruba SSO em todos os gateways
- [x] 6.4 Auditoria: sessões (SSH/RDP) gravadas e reproduzíveis
  - Validado com `deploy/validation/audit-replay-e2e.sh` (2026-07-10)
  - Warpgate: `recordings.enable: true` + path `/data/recordings`; API admin `sessions/{id}/recordings` + metadata; artefato NDJSON em disco
  - Guacamole: extensão `recording-storage`, params `recording-path`/`typescript-path` em `lab-ssh-browser`, volume `/recordings`, tabelas `guacamole_*_history`
  - Deploy garante recordings via `deploy/warpgate/deploy.sh` (idempotente)
- [x] 6.5 Confirmar: nenhuma credencial de alvo exposta ao dev em nenhum fluxo
