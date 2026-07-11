# ADR-008 — Cliente operador híbrido (browser + desktop) multi-OS

- **Status:** Aceito
- **Data:** julho de 2026
- **Relacionado:** ADR-006 (frontend), ADR-007 (Guacamole OIDC), CONSTITUTION §4 (SSO / zero target creds), `add-identity-axis`, OpenSpec `openspec/changes/add-operator-client-access-standard/`, conectividade por cliente (VPN/túnel)

## Contexto

A equipe IntegrAllTech opera **100% remota**. Os **alvos** (VPS, app, banco) dos clientes são, na prática, **Linux** (com exceção de desktops Windows via RDP quando o serviço do cliente exige).

Alguns clientes só expõem terminais/serviços **atrás de VPN**. A tentação operacional é “cada dev sobe a VPN e usa o app que quiser no IP interno”. Isso conflita com o modelo ArchGate:

- acesso privilegiado via **bastion** (Warpgate + Guacamole);
- **sem credencial de alvo no endpoint**;
- identidade central (Kanidm / ArchGuard);
- auditoria / gravação no gateway;
- multi-tenant e offboarding por identidade.

Ao mesmo tempo, nem todo protocolo precisa ser **clientless (browser)**:

- **SSH e bancos** funcionam bem com ferramentas desktop universais apontando no bastion;
- **RDP** beneficia-se fortemente de sessão no browser (sem instalar cliente RDP em Linux/macOS/Windows).

O “multi-OS” refere-se ao **notebook do operador** (Linux, macOS, Windows), não ao SO do servidor alvo.

## Decisão

### 1. Dois lados distintos

| Lado | SO típico | Papel |
|------|-----------|--------|
| **Servidor / alvo** | Linux (padrão); Windows só quando o serviço do cliente exige RDP | Hosts e serviços alcançados **pelo** bastion |
| **Cliente operador** | Linux, macOS ou Windows | Browser e/ou apps **padrão** até o **ArchGate**, nunca acesso direto privilegiado ao alvo como fluxo padrão |

### 2. Acesso privilegiado sempre pelo bastion

Fluxo padrão do operador:

```
Notebook (Linux | macOS | Windows)
  → autenticação ArchGate (SSO Kanidm onde disponível)
  → Warpgate e/ou Guacamole (targets autorizados)
  → [conectividade do site: VPN/túnel/connector]
  → alvo do cliente
```

**Proibido como padrão:** VPN do cliente no notebook + SSH/RDP/SQL **direto** no IP do alvo com credencial local.

### 3. Modelo híbrido de cliente (duas partes)

| Parte | Onde o operador trabalha | Protocolos / uso | Cliente suportado (oficial) |
|-------|--------------------------|------------------|-----------------------------|
| **A — Browser (clientless)** | Chrome / Firefox / Edge | RDP, VNC, SSH web; console ArchGuard; admin HTTPS via UI | Qualquer um dos três SO |
| **B — Desktop via bastion** | Apps nativos multiplataforma | SSH (OpenSSH → Warpgate); Postgres/MySQL (DBeaver ou equivalente → Warpgate) | Qualquer um dos três SO |

- **Primário para RDP:** Parte A (Guacamole / futura UnifiedUI).
- **Primário para SSH e DB:** Parte B (OpenSSH + cliente SQL), com Parte A (SSH web) como opção.
- Cliente RDP nativo (`mstsc`, Microsoft Remote Desktop, Remmina) é **opcional / avançado**, não o padrão (pior paridade multi-OS e gravação).

### 4. Conectividade VPN do cliente = config do site, não do operador

Na **configuração de acesso de cada cliente** entram, no mínimo:

1. Identidade / tenant / roles (quem pode operar);
2. **Conectividade** (como o ArchGate chega lá: peer VPN, tunnel agent, connector VM, etc.);
3. Targets (SSH, RDP, DB, HTTPS…);
4. Credenciais **somente** no gateway;
5. Policy (roles → targets; gravação).

- **Preferido:** uma conta/túnel VPN **institucional** no **connector** → N operadores via SSO no bastion.
- **Exceção documentada:** VPN de usuário no notebook quando o contrato do cliente **proíbe** connector — com inventário de targets, MFA, e plano de migração.

### 5. Multi-OS no client sem app proprietário ArchGate (Fase 1–3)

Não é obrigatório entregar um “ArchGate Desktop” nativo.

| Uso | Linux | macOS | Windows |
|-----|:-----:|:-----:|:-------:|
| Browser → console / Guacamole / Warpgate admin | ✓ | ✓ | ✓ |
| OpenSSH → `wg…:2222` (`usuario:target@host`) | ✓ | ✓ | ✓ (OpenSSH integrado) |
| Cliente SQL → proxy DB Warpgate | ✓ | ✓ | ✓ (DBeaver recomendado) |

Contrato de acesso **único** (mesmos hosts/portas/comandos); apêndices mínimos por SO só para UI do terminal.

### 6. SSO Guacamole (task 4.2) — fora do núcleo desta ADR

O gap OIDC implicit do Guacamole 1.6 permanece **ADR-007**. Esta ADR **não** exige resolver 4.2 para adotar o modelo híbrido:

- Personas SSH/DB podem operar **só Warpgate** (SSO Kanidm já ok);
- Personas RDP-browser usam Guacamole com as limitações atuais até proxy / 1.7 Code+PKCE / UnifiedUI.

### 7. Evolução (Fase 4)

UnifiedUI: catálogo único “minhas conexões” no ArchGate; embed de sessão gráfica; deep links / instruções copiáveis para Parte B. Engines (Warpgate/Guac) permanecem; a **cara** unifica.

## Consequências

### Positivas

- Time remoto multi-OS com o **mesmo** modelo operacional.
- Menos dependência de “instalar RDP client” e de VPN full no notebook.
- SSH/DB com ferramentas que o time já conhece, sem abrir mão do bastion.
- Onboarding de cliente inclui conectividade (VPN) como item de plataforma.
- Uma VPN/túnel institucional serve **N** operadores (identidade no Kanidm).

### Negativas / trade-offs

- Dois modos de uso (browser vs desktop) exigem **runbook** claro.
- RDP clientless ainda depende do Guacamole (e do gap SSO até remediação ADR-007).
- Exceções “VPN no notebook” precisam de governança (senão regridem ao anti-padrão).
- Clientes SQL/SSH devem ser **testados** contra o proxy Warpgate (TLS, auth do bastion).

### Neutras

- Servidor alvo Linux continua o caso default; não muda o footprint do Swarm ArchGate.

## O que precisa ser feito (plano de implementação)

### P0 — Documentação e política (já com infra Fase 1)

- [x] Formalizar esta ADR (ADR-008).
- [x] Runbook **Cliente operador (Linux / macOS / Windows)** — `documentos/runbooks/cliente-operador-multi-os.md`
  - URLs oficiais (`console`, `wg`, `guac`);
  - SSH OpenSSH → Warpgate (exemplo idêntico nos três SO);
  - SQL via Warpgate (host/porta/user de bastion; DBeaver);
  - RDP/SSH web via Guacamole (browser);
  - **Proibido:** IP direto do alvo / senha de root no notebook como padrão.
- [x] Runbook **Onboarding de cliente (site)** — `documentos/runbooks/onboarding-cliente-site.md`
  - checklist conectividade (connector VPN/túnel vs exceção VPN-user);
  - cadastro de targets (SSH, DB, RDP…);
  - roles Kanidm / Warpgate;
  - credenciais só no gateway.
- [x] Política de personas (Parte A browser / Parte B desktop / exceção VPN-user) — nas seções 3–4 desta ADR + runbooks.

### P1 — Padronização operacional (lab + staging)

- [ ] Congelar **clientes oficiais suportados**:
  - Browser: Chrome ou Firefox ESR/atual; Edge ok no Windows;
  - SSH: OpenSSH;
  - SQL: DBeaver Community (ou um único escolhido pelo time).
- [ ] Matriz de teste de aceitação multi-OS (1 host por SO do operador):
  - [ ] SSH target lab via Warpgate;
  - [ ] Postgres (ou MySQL) proxy via Warpgate;
  - [ ] SSH web e/ou RDP web via Guacamole (quando houver alvo).
- [ ] Snippets versionados em `deploy/runbooks/` (ou `documentos/runbooks/`):
  - `ssh-config.example` (Host wg / ProxyJump se aplicável);
  - string de conexão SQL de exemplo (sem segredos).
- [ ] Inventário por cliente: tipo de conectividade (`connector_peer` | `tunnel_agent` | `vpn_user_exception`).

### P2 — Produto / plataforma (conectar ao backlog de fases)

- [ ] **Targets por cliente** sempre com path de rede documentado (VPN/túnel no connector).
- [ ] Preferir **1 túnel institucional → N usuários ArchGate** em novos contratos.
- [ ] Warpgate: garantir targets SSH + DB por tenant de lab/produção com roles isoladas (já iniciado na Fase 1).
- [ ] Guacamole: conexões RDP/SSH browser por cliente quando houver alvo Windows/Linux gráfico.
- [ ] ADR-007 / 4.2: só priorizar oauth2-proxy ou Guac 1.7 Code+PKCE se a persona RDP-browser com SSO for crítica; caso contrário aceitar gap para quem usa só Warpgate.
- [ ] Fase 4 (UnifiedUI): catálogo unificado + embed Parte A + deep link Parte B (ADR-006).
- [ ] Fase rede (NetBird / mesh): connector por site como implementação padrão do item “conectividade” desta ADR.

### P3 — Fora de escopo desta decisão

- App desktop nativo “ArchGate.app” (Electron etc.) — não necessário para P0–P1.
- Substituir Guacamole por outro motor RDP — só se RDP clientless deixar de atender (avaliar à parte).
- Oracle / protocolos sem engine no Warpgate — ADR-001 e changes específicas.
- Forçar fork GUACAMOLE-2258 — não é pré-requisito deste modelo híbrido.

## Critérios de aceite (definição de pronto do modelo)

1. Operador em **Linux, macOS e Windows** consegue, com a doc oficial, abrir pelo menos **um** target SSH de lab via Warpgate **sem** VPN do cliente no notebook (lab IntegrAllTech).
2. O mesmo para **um** target de banco via proxy Warpgate (quando provisionado).
3. RDP ou SSH web documentado via browser no Guacamole (lab).
4. Template de onboarding de cliente lista **conectividade** + targets + roles.
5. Runbook declara explicitamente o anti-padrão (VPN + acesso direto) e a exceção controlada.

## Referências

- `adr/ADR-007-guacamole-oidc-implicit-vs-kanidm.md`
- `deploy/archguard-integration.md`
- `openspec/changes/add-identity-axis/tasks.md`
- Warpgate: SSH / PostgreSQL / MySQL / HTTP targets  
- Guacamole: RDP / VNC / SSH browser + recording
