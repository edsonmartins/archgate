# ArchGate — Pacote de Especificação e Governança

Plataforma de acesso privilegiado (bastion/gateway) da IntegrAllTech. Este pacote contém tudo o que é necessário para iniciar a implementação, no padrão spec-driven.

## Por onde começar

1. **`INICIAR_ARCHGATE.md`** — prompt de início. Cole no Claude Code (ou use como base de sessão).
2. **`CONSTITUTION.md`** — invariantes do projeto (precede tudo).
3. **`PLATAFORMA_ACESSO_PRIVILEGIADO.md`** — documento de arquitetura completo.
4. **`openspec/project.md`** — contexto de stack, repo e convenções (contém as decisões de ambiente `[A DEFINIR]`).
5. **`openspec/changes/README.md`** — índice das fases e ordem de execução.
6. **`MATRIZ_FUNCIONALIDADES.md`** — o que está **feito** vs **falta** no lab (atualizado com o progresso de implementação).
7. **`PLAN-HOMOLOGACAO-MVP.md`** — plano com tarefas F0–F5 até produto **homologável** (não confundir com lab nem com Fases 4–5).
8. **`PLAN-PRODUTO-100.md`** — plano do que falta até **100% do produto** (ondas W0–W5, OpenSpec completo).

## Conteúdo

```
CONSTITUTION.md                      invariantes de projeto
INICIAR_ARCHGATE.md                  prompt de início (kickoff)
PROMPT_EXECUCAO_CLAUDE_CODE.md       prompt de execução (regras de trabalho)
PLATAFORMA_ACESSO_PRIVILEGIADO.md    documento de arquitetura
adr/
  ADR-001-oracle-database-via-java-proxy.md   Oracle via proxy Java (aceito)
  ADR-003-persistencia-externa-postgresql.md  PostgreSQL externo (aceito)
  ADR-005-nome-do-produto-archgate.md         nome ArchGate (aceito)
openspec/
  project.md                         contexto/convenções + decisões de ambiente
  changes/
    README.md                        índice das fases
    add-identity-axis/               Fase 1 — identidade
    add-ephemeral-credentials/       Fase 2 — OpenBao (SSH CA + DB dinâmico)
    add-oracle-credential-proxy/     Fase 3 (pré-req) — proxy Java Oracle
    add-network-mesh/                Fase 3 — NetBird + cobertura de protocolo
    add-unified-ui-and-orchestration/ Fase 4 — UnifiedUI + orquestração
    add-agentic-access/              Fase 5 — HA + agêntico
```

## Estado das decisões

- **Aceitas:** ADR-001 (Oracle), ADR-003 (persistência), ADR-005 (nome ArchGate).
- **Diferidas por fase:** ADR-002 (step-ca, Fase 2), ADR-004 (fronteira ArchGuard × Mentors Axis, antes da Fase 4), ADR-006 (frontend, Fase 4). Não bloqueiam o início da Fase 1.

## Pré-requisitos de ambiente (só você decide)

Antes do primeiro código, confirmar em `openspec/project.md`: estrutura de repositório, alvo de deploy/DNS/TLS, segredos de bootstrap, alvos de teste (SSH/RDP/PostgreSQL) e pinning de versões. O prompt de início trata isso como passo 0.
