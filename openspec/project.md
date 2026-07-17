# project.md — ArchGate

Contexto e convenções do projeto, lido pelo ferramental OpenSpec e pelo Claude Code. Para invariantes, ver `CONSTITUTION.md` (precede este arquivo). Para arquitetura, `PLATAFORMA_ACESSO_PRIVILEGIADO.md`.

## Visão geral

ArchGate é a plataforma de acesso privilegiado (bastion/gateway) da IntegrAllTech. Desenvolvedores acessam máquinas, bancos, Kubernetes e painéis de clientes sem ver a credencial do alvo; offboarding é central; tudo é auditado. ArchGuard é o módulo de identidade dentro do ArchGate.

## Stack técnica

- **Backend:** Java 21 + Spring Boot 3.x.
- **Frontend:** React 18/19 + TypeScript + Mantine v9 (Archbase quando aplicável).
- **Banco:** PostgreSQL 15+ (externo, para Warpgate/Guacamole e serviços próprios).
- **Plugin de banco Oracle:** plugin Go fino (interface dbplugin v5) + proxy Java (ojdbc thin). Ver ADR-001.
- **Deploy:** Docker Swarm + Traefik (roteamento/TLS de borda).
- **Observabilidade:** VictoriaMetrics + Grafana + Loki + Tempo.
- **IA local (Fase 5):** vLLM na infraestrutura própria (RTX 3060 / Mac Mini M4).

## Componentes (engines operados, não reescritos)

| Componente | Papel | Licença |
|---|---|---|
| Kanidm | Identidade / OIDC (via ArchGuard) | MPL-2.0 |
| OpenBao | Segredos efêmeros (SSH CA, DB dinâmico) | MPL-2.0 |
| Warpgate | Gateway SSH/HTTPS/K8s/MySQL/PostgreSQL | Open-source |
| Apache Guacamole | Gateway RDP/VNC/SSH (browser) | Apache 2.0 |
| NetBird | Malha WireGuard | BSD-3 |
| ArchGuard | **Produto de identidade** (Kanidm + Console + AliasVault) — repo `../archguard` | Proprietário |
| Mentors Axis | Plano de controle / tenants (interno) | Proprietário |

### Fronteira ArchGuard × ArchGate (obrigatória)

- **ArchGuard** é a fonte de verdade de identidade: Kanidm (OIDC/API), console operador, service accounts, RBAC (`archguard_*`).
- **ArchGate** opera gateways (Warpgate/Guacamole), rede e (Fase 2+) OpenBao. **Não** sobe um segundo Kanidm nem reimplementa o console IAM.
- Integração: clients OIDC `warpgate` / `guacamole` / `archguard-console` no Kanidm do ArchGuard; `ARCHGUARD_ID_URL` = issuer (`id.archgate.com.br`).
- Detalhes: `deploy/archguard-integration.md`.

## Estrutura de repositório

**Decisão: monorepo** (confirmado no kickoff 2026-07-10).

```
/openspec/            # governança: changes/, specs/ (baseline), project.md
/adr/                 # decisões de arquitetura (ADR-001, ADR-005, ...)
/services/
  /oracle-proxy/      # proxy Java (Spring Boot) + ojdbc thin
  /openbao-oracle-plugin/  # plugin Go fino (dbplugin v5)
  /orchestration/     # integração Mentors Axis (Spring Boot)
  /agent-control/     # OpenSRE HITL / kill-switch / policy (Spring Boot) — Fase 5
/frontend/            # UnifiedUI (React/TS) — Fase 4
/deploy/              # Docker Swarm stacks + Traefik + secrets
CONSTITUTION.md
PLATAFORMA_ACESSO_PRIVILEGIADO.md
PROMPT_EXECUCAO_CLAUDE_CODE.md
```

## Convenções

- **Idioma:** documentação e specs em pt-BR; código/identificadores em inglês.
- **Specs (OpenSpec):** `changes/<verbo-kebab>/` com `proposal.md`, `design.md`, `tasks.md`, `specs/<capability>/spec.md`. Requisitos com `### Requirement:` + ao menos um `#### Scenario:` (WHEN/THEN). `MODIFIED` reescreve o requisito completo.
- **Fluxo:** ler proposal → design → specs → tasks; implementar uma tarefa por vez; marcar `[x]` só após validar o cenário.
- **Commits:** referenciar o change e a tarefa (ex.: `add-identity-axis #2.5`).
- **Versões:** pinadas em `deploy/versions.env` (sem `latest`).

## Decisões de ambiente (kickoff 2026-07-10)

| Item | Decisão |
|---|---|
| Estrutura de repositório | **Monorepo** |
| Alvo de deploy | **Docker Swarm** no host ArchGate |
| DNS / TLS | Domínio **archgate.com.br** + Traefik/Let's Encrypt e/ou **Cloudflare Tunnel** (já presente no host) |
| Segredos de bootstrap | Arquivo bootstrap **fora do git** + **SOPS/age**; Swarm secrets no deploy |
| Alvos de teste | Hosts de lab + containers de teste; lab PG no Postgres compartilhado |
| Pinning de versões | Sim — ver `deploy/versions.env` |

### Topologia de hosts (confirmada)

| Papel | Host | Hostname / notas |
|---|---|---|
| **ArchGate runtime** (Swarm, Traefik, Kanidm, Warpgate, Guacamole) | `192.168.1.180` | `edson-ai` — VPS local dedicada ao produto |
| **Infra compartilhada** (PostgreSQL externo, etc.) | `192.168.1.110` | Swarm/infra legada; `root-postgres-1` (`postgres:16`) em **:5434** |

PostgreSQL ArchGate **não** sobe container novo: reutiliza o Postgres em `.110:5434` com databases/roles isolados `warpgate` e `guacamole` (ADR-003).

### Hostnames públicos

Domínio base: **`archgate.com.br`**

- `id.archgate.com.br` — Kanidm
- `wg.archgate.com.br` — Warpgate
- `guac.archgate.com.br` — Guacamole
- `console.archgate.com.br` — ArchGuard

Exposição pública preferencial via Cloudflare Tunnel no host `.180` (padrão já usado para `*.archflow.com.br`). TLS de borda Cloudflare; origem LAN em Traefik/HTTP conforme stack.

### Versões pinadas

| Componente | Versão |
|---|---|
| PostgreSQL | 16.9-alpine |
| Traefik | v3.4.1 |
| Kanidm | 1.10.4 |
| Warpgate | v0.26.1 |
| Guacamole / guacd | 1.6.0 |

## Decisões (ADRs)

- **Aceitos:** ADR-001 (Oracle via proxy Java), ADR-003 (persistência externa PostgreSQL), ADR-005 (nome ArchGate).
- **Em aberto (por fase):** ADR-002 (step-ca — Fase 2), ADR-004 (fronteira ArchGuard × Mentors Axis — antes da Fase 4), ADR-006 (estratégia de frontend — Fase 4).
