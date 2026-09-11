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
| archguard | Identidade / OIDC (via ArchGuard) | MPL-2.0 |
| OpenBao | Segredos efêmeros (SSH CA, DB dinâmico) | MPL-2.0 |
| Warpgate | Gateway SSH/HTTPS/K8s/MySQL/PostgreSQL | Open-source |
| Apache Guacamole | Gateway RDP/VNC/SSH (browser) | Apache 2.0 |
| NetBird | Malha WireGuard | BSD-3 |
| ArchGuard | Console/identidade (interno) | Proprietário |
| Mentors Axis | Plano de controle / tenants (interno) | Proprietário |

## Estrutura de repositório

**Padrão sugerido: monorepo** (coordena mudanças cross-component via specs; recomendado para o fluxo spec-driven com Claude Code). Confirmar antes do kickoff — **[A DEFINIR]**.

```
/openspec/            # governança: changes/, specs/ (baseline), project.md
/adr/                 # decisões de arquitetura (ADR-001, ADR-005, ...)
/services/
  /oracle-proxy/      # proxy Java (Spring Boot) + ojdbc thin
  /openbao-oracle-plugin/  # plugin Go fino (dbplugin v5)
  /orchestration/     # integração Mentors Axis (Spring Boot)
/frontend/            # UnifiedUI (React/TS) — Fase 4
/deploy/              # Docker Swarm stacks + Traefik + IaC (Terraform)
CONSTITUTION.md
PLATAFORMA_ACESSO_PRIVILEGIADO.md
PROMPT_EXECUCAO_CLAUDE_CODE.md
```

## Convenções

- **Idioma:** documentação e specs em pt-BR; código/identificadores em inglês.
- **Specs (OpenSpec):** `changes/<verbo-kebab>/` com `proposal.md`, `design.md`, `tasks.md`, `specs/<capability>/spec.md`. Requisitos com `### Requirement:` + ao menos um `#### Scenario:` (WHEN/THEN). `MODIFIED` reescreve o requisito completo.
- **Fluxo:** ler proposal → design → specs → tasks; implementar uma tarefa por vez; marcar `[x]` só após validar o cenário.
- **Commits:** referenciar o change e a tarefa (ex.: `add-identity-axis #2.5`).
- **Versões:** fixar (pin) as versões dos componentes — evitar `latest`. **[A DEFINIR — fixar versões de archguard/OpenBao/Warpgate/Guacamole/NetBird]**.

## Decisões de ambiente (pré-requisitos do kickoff)

Necessárias antes de o Claude Code começar de fato:

- **Estrutura de repositório** (monorepo vs polyrepo) — **[A DEFINIR]**.
- **Alvo de deploy, domínios (DNS) e TLS** (Swarm onde? quais hosts para archguard/Warpgate/Guacamole? TLS via Traefik/Let's Encrypt?) — **[A DEFINIR]**.
- **Segredos de bootstrap** (raiz/unseal do OpenBao, admin) guardados fora da plataforma — **[A DEFINIR]**.
- **Alvos de teste** (host SSH, host Windows RDP, PostgreSQL de teste) para validar as tarefas 3.6/4.4/6.x da Fase 1 — **[A DEFINIR]**.
- **Pinning de versões** dos componentes — **[A DEFINIR]**.

## Decisões (ADRs)

- **Aceitos:** ADR-001 (Oracle via proxy Java), ADR-003 (persistência externa PostgreSQL), ADR-005 (nome ArchGate).
- **Em aberto (por fase):** ADR-002 (step-ca — Fase 2), ADR-004 (fronteira ArchGuard × Mentors Axis — antes da Fase 4), ADR-006 (estratégia de frontend — Fase 4).
