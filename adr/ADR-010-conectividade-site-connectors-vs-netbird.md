# ADR-010 — Conectividade multi-site: connectors por site vs NetBird

| Campo | Valor |
|-------|--------|
| Status | **Aceito (W2)** |
| Data | 2026-07-17 |
| Decisores | Arquitetura ArchGate |
| Relacionados | ADR-008, `add-network-mesh`, PLAN-PRODUTO-100 W2-MESH |

## Contexto

A especificação Fase 3 prevê **NetBird** (malha WireGuard self-hosted) para alcançabilidade multi-site. O lab já valida **1 connector / site** (WG, OpenVPN, scaffold Forti) no padrão ADR-008: N operadores só via bastion.

## Opções

| Opção | Descrição |
|-------|-----------|
| **A. NetBird first** | Control plane mesh + agents em todos os sites antes de onboarding cliente |
| **B. Connectors por site (default)** | Peer/VPN institucional **por site** no connector ArchGate; malha opcional depois |
| **C. Híbrido** | Connectors para VPN legada; NetBird só onde cliente aceita agent mesh |

## Decisão

**B + C seletivo:**

1. **Default W2/M2–M3:** **1 connector institucional por site** (`connector_peer` ou `tunnel_agent`) — stacks OpenVPN / WireGuard / openfortivpn conforme o cliente.  
2. **NetBird** fica **opcional** (W2-MESH02+) quando: multi-site denso, peer WG nativo em massa, ou política de malha zero-trust exigir.  
3. **Não** bloquear onboarding do 1º/2º cliente real à espera de NetBird.

## Consequências

- Onboarding: `onboarding-cliente-peer.md` + ficha `reais/*.yaml`.  
- Segmentação: connector **não** entra na LAN do site (invariante lab WG); rotas só subnets de targets.  
- Inventário: `clientes-reais-por-stack.md` é SoT de **qual stack** por site.  
- NetBird: proposal em `openspec/changes/add-network-mesh` permanece; implementação quando prioridade de negócio subir.

## Alternativas rejeitadas (por ora)

- VPN no notebook do operador como default (proibido ADR-008).  
- Um único tunnel global sem isolamento tenant.
