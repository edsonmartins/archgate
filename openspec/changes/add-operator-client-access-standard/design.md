# Design — Operator Client Access Standard

## Contexto

Padrão transversal (operacional + produto) sobre a stack já definida nas fases. Não introduz engine novo: fixa **como** o operador e o site se conectam ao ArchGate.

Decisão de arquitetura canônica: **ADR-008**.

## Decisões técnicas

### D1 — Bastion-first, sempre

Todo acesso privilegiado a alvos de cliente passa por **Warpgate** e/ou **Guacamole** (e, na Fase 4, UnifiedUI sobre esses engines). O notebook do operador **não** é peer privilegiado da rede do cliente no fluxo padrão.

### D2 — Separar “client operador” de “server alvo”

| Lado | SO | Implicação de suporte |
|------|-----|------------------------|
| Operador (client) | Linux, macOS, Windows | Paridade de **acesso** (browser + OpenSSH + SQL client) |
| Alvo (server) | Linux padrão; Windows se RDP | Targets e conectividade do site |

### D3 — Híbrido Parte A / Parte B

| Parte | Primário para | Implementação atual | Evolução |
|-------|---------------|---------------------|----------|
| A Browser | RDP, VNC, SSH web, console | Guacamole + ArchGuard console | UnifiedUI embed (Fase 4) |
| B Desktop | SSH, Postgres/MySQL | OpenSSH + DBeaver → Warpgate | Deep links no catálogo (Fase 4) |

RDP nativo no desktop = opcional/avançado, não padrão (pior paridade e gravação).

### D4 — Clientes oficiais suportados (sem agente ArchGate)

- Browser: Chrome ou Firefox (Edge ok no Windows).
- SSH: OpenSSH (nativo nos três SO).
- SQL: DBeaver Community (ou um único fixado pelo time); CLI `psql`/`mysql` aceitos.

Não exigir “ArchGate.app” nas fases 1–3.

### D5 — VPN/túnel é conectividade do **site**

Ficha de cliente inclui `conectividade.tipo`:

| Tipo | Código | Path de rede | Operador |
|------|--------|--------------|----------|
| Peer / site-to-site / WG permanente | `connector_peer` | Connector institucional | Só bastion |
| Agent no site (NetBird, cloudflared, jump) | `tunnel_agent` | Idem | Só bastion |
| VPN de usuário no notebook | `vpn_user_exception` | Endpoint do operador | Exceção + inventário + MFA + plano migração |

Preferido: **uma** conta/túnel institucional → **N** sessões de operadores via SSO Kanidm.

### D6 — Targets multi-protocolo pelo bastion

| Protocolo | Engine | Client operador |
|-----------|--------|-----------------|
| SSH | Warpgate | OpenSSH (B) ou browser (A) |
| PostgreSQL / MySQL | Warpgate | DBeaver / CLI (B) |
| HTTPS admin interno | Warpgate | Browser (A/B) |
| RDP / VNC | Guacamole | Browser (A) |
| Kubernetes API | Warpgate | kubectl via proxy (B), quando cadastrado |

### D7 — Relação com SSO Guacamole (ADR-007)

O padrão **não** bloqueia em 4.2:

- Personas SSH/DB: Warpgate + Kanidm (já alinhado).
- Personas RDP-browser: Guacamole com limitação atual até oauth2-proxy / Guac Code+PKCE / UnifiedUI.

### D8 — Artefatos normativos

| Artefato | Função |
|----------|--------|
| ADR-008 | Decisão |
| `documentos/runbooks/cliente-operador-multi-os.md` | Como o operador acessa |
| `documentos/runbooks/onboarding-cliente-site.md` | Como a plataforma cadastra o site |
| Esta change OpenSpec | Requisitos e tasks |

## Riscos e mitigações

| Risco | Mitigação |
|-------|-----------|
| Regressão a VPN+direto por hábito | Runbook + review de onboarding; exceções nomeadas |
| Cliente proíbe connector | `vpn_user_exception` com prazo e inventário |
| Warpgate TLS/auth incompatível com DBeaver | Matriz de teste P1; doc de conexão |
| Paridade Windows OpenSSH | Checklist Windows Terminal + OpenSSH Client opcional feature |
| Auditoria do cliente só vê IP do connector | Alinhar expectativa; auditoria por pessoa no ArchGate |

## Fora de escopo

- Implementação NetBird completa (Fase 3 / `add-network-mesh`) — esta change define o **contrato** de conectividade.
- UnifiedUI (Fase 4) — define requisitos que a UI unificada deverá respeitar.
- Credenciais efêmeras (Fase 2).
- Fork Guacamole OIDC.
