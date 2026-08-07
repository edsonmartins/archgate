# Tasks — Connect embedded sessions (RDM-lite)

> Reconstruído em 2026-07-29 a partir do código entregue e do quadro S0–S4 do
> ADR-008B. O pacote foi implementado sem `tasks.md` (auditoria 2026-07-28,
> CONSTITUTION §5.1); os itens marcados refletem o que **já está no código**,
> com o caminho do arquivo como evidência.

## 1. Shell multi-sessão (S1)

- [x] 1.1 Workspace de abas — `desktop/src/sessions/SessionWorkspace.tsx`
- [x] 1.2 Tipos de sessão por protocolo/engine — `desktop/src/sessions/types.ts`
- [x] 1.3 Estados connecting / error / reconnect por aba
- [x] 1.4 “Abrir externo” preservado como fallback — `internal/cli/connect.go`
- [x] 1.5 Fechar aba encerra PTY/túnel — `src-tauri/src/ssh_session.rs`

## 2. SSH embutido (S2a)

- [x] 2.1 Terminal xterm.js — `desktop/src/sessions/SshTerminal.tsx`
- [x] 2.2 Sidecar PTY em Rust (`ssh -tt`) — `src-tauri/src/ssh_session.rs`
- [x] 2.3 Usuário do bastion `user:target@wg` (não o nickname do catálogo)
- [x] 2.4 Prompt de senha do Warpgate sem persistir — `WgPasswordTip.tsx`
- [x] 2.5 Preferências de terminal (fonte/tema) — `desktop/src/prefs/`

## 3. Guacamole embutido (S2b)

- [x] 3.1 Canvas `guacamole-common-js` — `desktop/src/sessions/GuacSession.tsx`
- [x] 3.2 Túnel curto via BFF `POST /api/unified/v1/sessions` — `sessions/api.ts`
- [x] 3.3 Fullscreen + notificação de sessão
- [x] 3.4 Smoke do token Guac — `deploy/validation/smoke-f4-guac-ws.sh`

## 4. DB e Web (S4)

- [x] 4.1 `psql` embutido via PTY — `desktop/src/sessions/DbTerminal.tsx`
- [x] 4.2 MySQL via bastion Warpgate — `documentos/runbooks/warpgate-mysql-bastion.md`
- [x] 4.3 Web/Oracle em iframe — `desktop/src/sessions/WebSession.tsx`

## 5. Autenticação do operador

- [x] 5.1 Login OIDC Code+PKCE — `internal/oidc/pkce.go`
- [x] 5.2 Refresh de token — `internal/oidc/refresh.go`
- [x] 5.3 Bearer no BFF (`auth-header`) — `internal/api/client.go`
- [x] 5.4 Caminho de laboratório com segredo compartilhado e fail-closed
      — `internal/cli/login.go` (auditoria 2026-07-28, P0-1)
- [ ] 5.5 Autenticação Warpgate por chave/agent, sem prompt de senha (S3)

## 6. Empacotamento e distribuição

- [x] 6.1 `.app`/`.dmg` locais — `scripts/package-macos.sh`
- [x] 6.2 Verificação de atualização — `desktop/src/updateCheck.ts`
- [x] 6.3 Iconset macOS íntegro (`iconutil` gera o `.icns`)
      — corrigido na auditoria 2026-07-28
- [ ] 6.4 Developer ID + notarização real (depende de conta Apple da org)
- [ ] 6.5 Empacotamento Windows/Linux

## 7. Validação

- [x] 7.1 Suíte Onda 3 — `deploy/validation/smoke-onda3-connect.sh`
- [x] 7.2 Testes de dispatch por protocolo — `internal/cli/dispatch_test.go`
- [x] 7.3 Testes de sessão/credencial — `internal/cli/session_test.go`
- [x] 7.4 Regressão do bearer de laboratório — `internal/cli/cli_test.go`
- [ ] 7.5 E2E com host Windows real (RDP ponta a ponta) — depende de host
