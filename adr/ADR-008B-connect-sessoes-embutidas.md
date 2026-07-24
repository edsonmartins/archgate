# ADR-008B — ArchGate Connect: sessões embutidas (RDM-lite)

- **Status:** Aceito (direção de produto)
- **Data:** 2026-07-20
- **Emenda a:** [ADR-008A](./ADR-008A-archgate-connect-cliente-operador.md)
- **Relacionado:** ADR-006 (UnifiedUI / guacamole-common-js), ADR-008 (bastion-first)

## Contexto

O Connect v0.2 é um **lançador**: SSH no Terminal.app, RDP/Guac no browser, DB via snippet.  
O operador pede experiência tipo **Remote Desktop Manager**: várias sessões **dentro** do app.

## Decisão

1. **Connect passa a ser console multi-sessão embutida** (além do CLI launcher).
2. **SSH Warpgate** → `xterm.js` + cliente SSH local (sidecar) para `user:target@bastion:2222`.
3. **RDP / VNC / SSH-guac** → `guacamole-common-js` (padrão UnifiedUI) + túnel BFF curto.
4. **Postgres / Oracle / HTTP** → v1 painel + external/open; terminal `psql` embutido depois.
5. **MVP em paralelo** SSH + Guac na UI multi-aba (S1 shell → S2a/S2b).
6. **Auth operador no Warpgate (camada A):**
   - MVP: **prompt de senha** no Connect se publickey/agent não autenticar;
   - **não** gravar senha WG no keychain no primeiro corte;
   - OIDC (catálogo) permanece separado.
7. CLI e “Open external” **permanecem** como fallback e automação.

## Fora de escopo (MVP)

- Vault local de senhas de alvo (RDM full)
- VPN no notebook
- FreeRDP nativo (Guac cobre RDP)
- Notarize / multi-OS tray (já residual à parte)

## Consequências

- UI Connect cresce (tabs, PTY, canvas); precisa de BFF `/sessions` robusto para Guac.
- Senha Warpgate no processo do app — política de não logar e TTL de sessão claro.
- Reuso de componentes UnifiedUI reduz drift de Guac.

## Aceite

Ver OpenSpec `add-connect-embedded-sessions` e plano de implementação S0–S4.

## Status de implementação

| Fase | Conteúdo | Estado |
|------|----------|--------|
| S0 | ADR-008B + OpenSpec | Feito |
| S1 | UI multi-aba + fallback externo | Feito |
| S2a | SSH embutido (xterm + PTY + `ssh -tt` Warpgate) | Feito |
| S2b | Guacamole RDP/VNC embutido (WS + iframe SSO no app) | Feito (2026-07-24) |
| S3 | Auth polish (agent/key, sem persistir senha) | Pendente |
| S4 | DB/psql embutido (PTY) + Web/Oracle iframe | Feito (2026-07-24) |
