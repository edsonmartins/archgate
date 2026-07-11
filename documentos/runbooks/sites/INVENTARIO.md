# Inventário de sites / clientes (conectividade)

> ADR-008 · OpenSpec `add-operator-client-access-standard` tasks 3.1–3.3  
> Atualizar a cada onboarding ou mudança de path de rede.

## Clientes reais por stack de VPN

**Fonte principal (produção):** [clientes-reais-por-stack.md](./clientes-reais-por-stack.md)  
Fichas: [reais/](./reais/) · Template: [cliente-site.template.yaml](./cliente-site.template.yaml)

O restante deste arquivo descreve o **lab/staging**. Não misturar com produção.

## Tipos de conectividade

| Código | Descrição | Operador usa VPN do cliente? |
|--------|-----------|------------------------------|
| `connector_peer` | Peer site-to-site / WireGuard permanente no connector | **Não** |
| `tunnel_agent` | Agent/jump **ou** cliente VPN institucional (OpenVPN / openfortivpn / …) no connector | **Não** (padrão) |
| `vpn_user_exception` | VPN de usuário no notebook (exceção) | **Sim** |

### Stacks reais dos clientes (hoje)

| Stack | Tipo ADR-008 usual | Doc |
|-------|-------------------|-----|
| **WireGuard** | `connector_peer` (preferido) | peer lab + template |
| **OpenVPN** | `tunnel_agent` | cliente OpenVPN no connector |
| **openfortivpn** | `tunnel_agent` | Forti SSL no connector |

Guia: [conectividade-vpn-clientes.md](./conectividade-vpn-clientes.md).  
**Não** instalar OpenVPN/WG/Forti no notebook do operador no fluxo padrão.

## Preferência contratual (task 3.3) — OBRIGATÓRIA em novos contratos

1. **Padrão:** uma conectividade institucional (`connector_peer` ou `tunnel_agent`) → **N operadores** ArchGate com SSO individual.
2. **Proibido como default:** compartilhar conta VPN de usuário entre notebooks do time.
3. **Exceção:** `vpn_user_exception` só se o cliente **recusar** connector; registrar em [vpn-user-exceptions.md](./vpn-user-exceptions.md) com inventário de hosts, MFA, dono e **prazo de migração**.
4. Texto sugerido ao cliente: ver runbook [onboarding-cliente-site.md](../onboarding-cliente-site.md).

## Sites ativos (staging / lab IntegrAllTech)

| Site / slug | Tenant Kanidm | Conectividade | Targets Warpgate | Guac | Ficha |
|-------------|---------------|---------------|------------------|------|-------|
| Rio Quality (lab) | `tenant_rio_quality` | `tunnel_agent` (overlay Swarm + Postgres `.110`) | `rio-lab-ssh`, `rio-lab-postgres` | `lab-ssh-browser` (shared lab) | [lab-rio-quality.yaml](./lab-rio-quality.yaml) |
| Grupo Marra (lab) | `tenant_grupo_marra` | `tunnel_agent` (mesmo runtime) | `marra-lab-ssh`, `marra-lab-postgres` | — | [lab-grupo-marra.yaml](./lab-grupo-marra.yaml) |
| **Piloto connector** | `tenant_rio_quality` | **`tunnel_agent` + LAN isolada** (`archgate-site-piloto`) | **`piloto-lab-ssh`** via connector | — | [lab-piloto-connector.yaml](./lab-piloto-connector.yaml) |
| Lab genérico | (roles admin/operators) | `tunnel_agent` | `lab-ssh`, `lab-postgres` | `lab-ssh-browser` | (sem ficha tenant) |

### Notas de path de rede (lab)

- **Não** há VPN de cliente real no lab atual.
- SSH lab: container na rede `archgate-data` (ex. `10.0.2.99:2222`) — alcançável só do runtime/Swarm, **não** exposto como “IP do cliente ao operador”.
- Postgres lab: `192.168.1.110:5434` alcançável do runtime; operador usa **proxy** `WG:55432`.
- Produção futura com VPN de cliente: classificar `connector_peer` ou `tunnel_agent` e **não** publicar IPs internos nos runbooks de operador.

## Exceções VPN-user

Ver [vpn-user-exceptions.md](./vpn-user-exceptions.md).  
**Atual (2026-07-10):** nenhuma exceção ativa no inventário ArchGate lab.

## Smoke conectividade site (task 3.4)

| Cenário | Status |
|---------|--------|
| Target SSH só via path lab (container overlay) | **PASS** — operador usa Warpgate `rio-lab-ssh` |
| **LAN site isolada + connector** (piloto) | **PASS** 2026-07-10 — `smoke-connector-piloto.sh`: site fora de `archgate-data`; path data→connector→site; `testuser:piloto-lab-ssh` |
| Piloto **WireGuard** (connector fora da site-net) | **PASS** 2026-07-11 — `deploy-wg-piloto-lab.sh` + smoke MODE=wireguard |
| Piloto **OpenVPN** (client no connector) | **PASS** 2026-07-11 — `deploy-openvpn-piloto-lab.sh` + smoke MODE=openvpn |
| Scaffold **openfortivpn** | Template + unit — E2E no 1º site Forti |
| Cliente real OpenVPN / WG / openfortivpn | **Pendente produção** — ver `conectividade-vpn-clientes.md` + onboarding |

## Roles Warpgate (referência)

| Role | Targets (API roles) |
|------|---------------------|
| `tenant-rio-quality` | `rio-lab-ssh`, `rio-lab-postgres` |
| `tenant-grupo-marra` | `marra-lab-ssh`, `marra-lab-postgres` |
| `admin` / `archgate-operators` | conforme policy lab |

Última revisão: 2026-07-11
