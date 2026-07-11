# ADR-003 — Persistência externa (PostgreSQL) para Warpgate e Guacamole

- **Status:** Aceito
- **Data:** julho de 2026
- **Relacionado:** CONSTITUTION §4.3; Fase 1 (`add-identity-axis`), Fase 5 (`add-agentic-access`, HA)

## Contexto

O Warpgate usa SQLite por padrão para configuração, auditoria e gravações. Isso é frágil para HA, backup e escala. O Guacamole também requer um backend de banco para autenticação/conexões/gravações. Ambos precisam de persistência confiável desde a Fase 1, e HA na Fase 5.

## Decisão

Warpgate e Guacamole SHALL usar **PostgreSQL externo** (não SQLite) em todos os ambientes a partir do primeiro deploy. Schemas separados por serviço no mesmo cluster PostgreSQL gerenciado pela IntegrAllTech.

## Consequências

**Positivas:** backup/restore consistentes; base para HA (Fase 5); auditoria e gravações confiáveis; alinhamento com a stack PostgreSQL da casa.

**Negativas / custos:** um PostgreSQL a operar e manter (já é padrão da casa, custo baixo); configuração explícita de conexão nos dois componentes.

## Riscos e mitigações

- **Ponto único de falha do PostgreSQL** → HA do banco na Fase 5; backup desde o início.
- **Migrações de schema** → versionar (Flyway) onde aplicável.

## Referências

- CONSTITUTION.md §4.3 (persistência externa como invariante).
- Documento de arquitetura, §12.
