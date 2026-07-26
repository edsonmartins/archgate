# Plataforma de Acesso Privilegiado — Pacotes de Mudança (OpenSpec)

Sequência de mudanças que constroem a plataforma, na ordem de dependência. Cada pacote segue o padrão OpenSpec (`proposal.md`, `tasks.md`, `design.md`, `specs/<capability>/spec.md`).

| Ordem | Change | Fase | Entrega |
|---|---|---|---|
| 1 | `add-identity-axis` | 1 — Identidade | Kanidm como IdP OIDC; Warpgate/Guacamole confiam nele; console ArchGuard. **Já resolve o núcleo do offboarding.** |
| 1b | `add-operator-client-access-standard` | 1 — Padrão operador | Bastion-first; client multi-OS; híbrido browser+desktop; VPN no site (ADR-008). **Lab-ready** (2026-07-10): smoke L+macOS, inventário sites; Windows waiver; mesh/UnifiedUI deferred. |
| 2 | `add-ephemeral-credentials` | 2 — Credenciais efêmeras | OpenBao lab **MVP** (2026-07-10): SSH CA + DB dinâmico + broker Warpgate + JWT←Kanidm + unseal timer; Warpgate nativo Vault/SSH cert ainda pendente. |
| 3a | `add-oracle-credential-proxy` | 3 — Pré-requisito Oracle | Proxy Java (ojdbc thin) para credencial dinâmica Oracle. Implementa o ADR-001. |
| 3 | `add-network-mesh` | 3 — Rede e protocolo | NetBird (malha); RDP/K8s ponta a ponta; Oracle via `add-oracle-credential-proxy`. |
| 4 | `add-unified-ui-and-orchestration` | 4 — UnifiedUI e orquestração | React + `guacamole-common-js`; automação via Mentors Axis. |
| 5 | `add-agentic-access` | 5 — Escala e agêntico | HA (OpenBao/Kanidm); OpenSRE como service account com HITL e kill-switch. |
| — | `add-org-credential-broker` | Control plane (paralelo) | Contas da IntegrAllTech (GCP/Play/Apple/produtos): inventário, OpenBao, checkout TTL, dual-control. **ADR-013**. |

## Capabilities e evolução

| Capability | Introduzida | Modificada em |
|---|---|---|
| `identity` | Fase 1 | — |
| `gateway-authentication` | Fase 1 | Fase 2 (credencial efêmera) |
| `access-console` | Fase 1 | Fase 4 (UnifiedUI); OCB (org accounts no Manager) |
| `operator-client-access` | Fase 1 (`add-operator-client-access-standard`) | Fase 3 (malha/connector), Fase 4 (UnifiedUI) |
| `ephemeral-credentials` | Fase 2 | Fase 3 (Oracle) |
| `oracle-credential-proxy` | Fase 3 (pré-req) | — |
| `network-reachability` | Fase 3 | — |
| `unified-ui` | Fase 4 | — |
| `orchestration` | Fase 4 | — |
| `agentic-access` | Fase 5 | — |
| `high-availability` | Fase 5 | — |
| `org-credential-broker` | Control plane (`add-org-credential-broker`) | — |

## Decisões (ver documento de arquitetura, §16)
- **ADR-001 (Oracle via OpenBao) — ACEITO:** proxy Java com JDBC thin. Ver `adr/ADR-001-oracle-database-via-java-proxy.md` e o pacote `add-oracle-credential-proxy`.
- **ADR-005 (nome) — ACEITO:** produto = **ArchGate**; ArchGuard é o módulo de identidade. Ver `adr/ADR-005-nome-do-produto-archgate.md` (pendente checagem de marca/domínio).
- **ADR-007 (Guacamole OIDC) — ACEITO:** implicit stock vs Kanidm; remediação proxy / 1.7 / UnifiedUI.
- **ADR-008 (cliente operador híbrido multi-OS) — ACEITO:** ver `add-operator-client-access-standard` e `adr/ADR-008-cliente-operador-hibrido-multi-os.md`.
- **ADR-013 (org credential broker) — PROPOSTO:** contas IntegrAllTech (cloud/lojas/produtos); ver `add-org-credential-broker`.
- Em aberto: ADR-002 (step-ca), ADR-003 (persistência Warpgate — de fato PostgreSQL em uso), ADR-004 (fronteira ArchGuard × Mentors Axis — antes da Fase 4), ADR-006 (estratégia de frontend).

## Referência
Documento de arquitetura completo: `PLATAFORMA_ACESSO_PRIVILEGIADO.md`.

**Matriz feito × falta (lab 2026-07-10):** [`documentos/MATRIZ_FUNCIONALIDADES.md`](../../documentos/MATRIZ_FUNCIONALIDADES.md).
