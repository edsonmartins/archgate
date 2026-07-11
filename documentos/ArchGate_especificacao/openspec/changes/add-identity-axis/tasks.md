# Tasks — Add Identity Axis (Fase 1)

## 1. Infraestrutura base
- [ ] 1.1 Provisionar PostgreSQL externo (schemas separados para Warpgate e Guacamole)
- [ ] 1.2 Definir stack Docker Swarm + Traefik (roteamento/TLS de borda) para os serviços da fase
- [ ] 1.3 Definir gestão de segredos de bootstrap (fora da plataforma que eles protegem)

## 2. Kanidm (identidade / OIDC)
- [ ] 2.1 Subir Kanidm com TLS e domínio próprio
- [ ] 2.2 Modelar tenants (um por cliente: Rio Quality, Grupo Marra, ...) como grupos/escopos
- [ ] 2.3 Definir papéis RBAC: Super Admin, Tenant Admin, Operador, Service Desk, Viewer
- [ ] 2.4 Criar service account de exemplo (base para agentes na Fase 5)
- [ ] 2.5 Registrar OAuth2/OIDC clients: `warpgate`, `guacamole`, `archguard-console`
- [ ] 2.6 Configurar fluxo Authorization Code + PKCE; desabilitar fluxos implícitos
- [ ] 2.7 Validar emissão de token e claims (grupos/tenant no token)

## 3. Warpgate (gateway SSH/HTTPS/K8s/DB)
- [ ] 3.1 Subir Warpgate apontando persistência ao PostgreSQL externo (não SQLite)
- [ ] 3.2 Configurar SSO provider = Kanidm (OpenID Connect)
- [ ] 3.3 Desabilitar autenticação local por senha (apenas SSO)
- [ ] 3.4 Habilitar gravação de sessão (live + replay)
- [ ] 3.5 Mapear papéis/grupos do Kanidm para RBAC de targets no Warpgate
- [ ] 3.6 Cadastrar 1 target SSH e 1 target PostgreSQL de teste (credencial detida pelo Warpgate)
- [ ] 3.7 Validar: dev autentica via SSO e abre sessão sem ver a credencial do alvo

## 4. Guacamole (gateway RDP/VNC/browser)
- [ ] 4.1 Subir guacd + webapp Guacamole apontando ao PostgreSQL externo
- [ ] 4.2 Instalar e configurar extensão OIDC (`openid`) apontando ao Kanidm
- [ ] 4.3 Habilitar gravação de sessão gráfica
- [ ] 4.4 Cadastrar 1 conexão RDP de teste (credencial injetada pelo gateway)
- [ ] 4.5 Validar: dev autentica via SSO e abre RDP sem ver a credencial do alvo

## 5. ArchGuard (console operador)
- [ ] 5.1 Configurar login do operador via OIDC (Kanidm)
- [ ] 5.2 Garantir padrão de token fora do browser (proxy server-side com validação de path)
- [ ] 5.3 Tela: Tenant Admin gerencia usuários/targets do próprio tenant
- [ ] 5.4 Tela: Operador vê apenas as conexões autorizadas
- [ ] 5.5 Expor operações base por API: provisionar/desabilitar usuário, conceder/revogar acesso

## 6. Validação de ponta a ponta
- [ ] 6.1 Login único: mesma identidade Kanidm acessa Warpgate, Guacamole e console
- [ ] 6.2 Isolamento: usuário do tenant A não enxerga targets do tenant B
- [ ] 6.3 **Offboarding:** desabilitar identidade no Kanidm derruba SSO em todos os gateways
- [ ] 6.4 Auditoria: sessões (SSH/RDP) gravadas e reproduzíveis
- [ ] 6.5 Confirmar: nenhuma credencial de alvo exposta ao dev em nenhum fluxo
