# Mapeamento conectividade ADR-008 → malha

> Contrato de conectividade de **site**. Stacks reais dos clientes hoje: **OpenVPN**, **WireGuard**, **openfortivpn** — ver `conectividade-vpn-clientes.md`.

| `conectividade.tipo` (ADR-008) | Stack típica do cliente | Implementação ArchGate | Notas |
|--------------------------------|-------------------------|------------------------|--------|
| `connector_peer` | **WireGuard** (peer dedicado) | Peer WG site ↔ connector; futuro NetBird | Preferido; lab: `deploy-wg-piloto-lab.sh` |
| `tunnel_agent` | **OpenVPN**, **openfortivpn**, NetBird, cloudflared | Agent/cliente VPN **no connector** (1 conta institucional) | Cliente “entra” na VPN; Warpgate só vê o connector |
| `vpn_user_exception` | Qualquer uma no **notebook do dev** | Fora do padrão; `vpn-user-exceptions.md` | Migrar para peer/agent |

### Lab piloto (atualizado 2026-07-11)

| Peça | Valor |
|------|--------|
| Path | `deploy-wg-piloto-lab.sh` — WireGuard real |
| Site net | `archgate-site-piloto` 10.77.10.0/24 |
| Alvo | `archgate-site-piloto_ssh` (só site) |
| Platform | `archgate-site-piloto_connector` (data + wg-lab, **não** site-net) |
| Agent | `archgate-site-piloto_agent` (site + wg-lab) |
| Target WG | `piloto-lab-ssh` → connector:2223 |
| Smoke | `smoke-connector-piloto.sh` MODE=wireguard **PASSED** |

## Requisitos preservados

- Operador **não** recebe rota full da LAN do cliente no modelo preferido.
- Targets Warpgate/Guac usam host **visto pelo connector** (nunca “IP só na VPN do notebook”).
- Isolamento multi-tenant: Kanidm + roles Warpgate; **um connector (ou VRF de rotas) por cliente**.
- A stack (OpenVPN / WG / Forti) é campo de inventário, não escolha do operador.
