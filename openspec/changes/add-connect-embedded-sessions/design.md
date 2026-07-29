# Design — Connect embedded sessions (RDM-lite)

> Escrito retroativamente em 2026-07-29. A auditoria de 2026-07-28 apontou que
> este pacote entregou o maior volume de código do repositório (~4,9k LoC no
> desktop Tauri) sem `design.md` nem `tasks.md`, violando a CONSTITUTION §5.1
> (proposal → design → specs → tasks). Este documento descreve a implementação
> **como ela existe hoje**, para que a spec e o código voltem a estar em
> sincronia (§5.3) — não é um plano de trabalho futuro.

Referências: [ADR-008B](../../../adr/ADR-008B-connect-sessoes-embutidas.md),
[ADR-008A](../../../adr/ADR-008A-archgate-connect-cliente-operador.md),
[ADR-006](../../../adr/ADR-006-estrategia-frontend-unifiedui.md).

## Contexto

O Connect nasceu como **lançador**: abria Terminal.app para SSH, browser para
Guacamole e imprimia snippet para DB. O operador pediu experiência tipo Remote
Desktop Manager — várias sessões dentro do próprio app — sem abandonar o
princípio bastion-first (ADR-008): o notebook nunca liga VPN de cliente.

## Objetivos

1. Múltiplas sessões simultâneas em abas, dentro do app.
2. Cobrir o happy path de SSH, RDP/VNC, DB e Web/Oracle sem UI de terceiros.
3. Manter “abrir externo” como fallback e caminho de automação (CLI).
4. Nenhum segredo de alvo persistido no cliente.

## Não-objetivos

- Vault local de senhas de alvo (RDM completo).
- VPN no notebook do operador.
- Cliente RDP nativo (FreeRDP) — Guacamole cobre RDP.
- Notarização/multi-OS, que é residual do ADR-008A.

## Arquitetura

```
ArchGate Connect (Tauri)
├── UI (React/TS)  ── desktop/src/
│   ├── catalog/            catálogo, ⌘K, favoritos
│   └── sessions/           SessionWorkspace = abas
│       ├── SshTerminal     xterm.js  ← PTY sidecar
│       ├── GuacSession     guacamole-common-js ← WS do BFF
│       ├── DbTerminal      xterm.js  ← psql via PTY
│       └── WebSession      iframe (HTTP target / Oracle UI)
├── Rust (src-tauri/)
│   └── ssh_session.rs      PTY: `ssh -tt user:target@bastion -p 2222`
└── CLI Go (internal/)      login OIDC, catálogo, print-ssh, auth-header
```

Fluxo de uma sessão:

1. UI pede o catálogo ao BFF (`GET /api/unified/v1/connections`), autenticada
   por OIDC Bearer obtido pelo CLI.
2. Ao abrir uma aba, a UI resolve o tipo do alvo pelo `protocol`/`engine`.
3. SSH/DB → comando PTY no processo Rust, sempre contra o **bastion**.
4. RDP/VNC/Guac → `POST /api/unified/v1/sessions` devolve túnel curto; o canvas
   conecta via `guacamole-common-js`.
5. Fechar a aba encerra o PTY/túnel; logout fecha todas e limpa credenciais.

## Decisões

| # | Decisão | Porquê |
|---|---------|--------|
| D1 | PTY com o binário `ssh` do SO, não biblioteca SSH embarcada | Reaproveita config/agent do operador e reduz superfície criptográfica própria |
| D2 | `guacamole-common-js` (mesmo componente da UnifiedUI) | Evita drift entre as duas superfícies (ADR-006) |
| D3 | Token de túnel só server-side; o app recebe material opaco e curto | CONSTITUTION §4.5 |
| D4 | Senha do Warpgate pedida em prompt, **não** persistida no keychain | ADR-008B item 6; reduz o valor de comprometer o endpoint |
| D5 | Endpoints restritos a bastion (Warpgate/Guac/console) | Impede que a app vire caminho alternativo à rede do cliente |
| D6 | “Abrir externo” permanece | Fallback quando o embed falha e caminho de automação |

## Segurança

- Nenhuma credencial de alvo chega ao app: o gateway injeta (CONSTITUTION §2.1).
- O BFF autentica por cookie ou Bearer OIDC. O caminho de laboratório exige
  segredo compartilhado e não concede tenant de cliente real
  (auditoria 2026-07-28, P0-1).
- A senha do Warpgate vive apenas na memória do processo durante a sessão.

## Riscos

| Risco | Mitigação |
|-------|-----------|
| Senha WG na memória do app | TTL de sessão curto; nunca logada; sem persistência |
| Divergência do embed Guac vs UnifiedUI | Mesmo componente e mesmo contrato de BFF |
| PTY dependente do `ssh` do SO | Detecção na primeira execução + fallback externo |
| Empacotamento macOS sem notarização | Residual conhecido (ADR-008A / tarefa 6.2) |

## Alternativas descartadas

- **FreeRDP nativo:** duplicaria o caminho que o Guacamole já cobre.
- **Biblioteca SSH em Rust:** perderia agent/config do operador por ganho baixo.
- **Só UnifiedUI no browser:** não atende o pedido de app multi-sessão local.
