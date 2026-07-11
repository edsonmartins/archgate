# Site connector (Fase 3 — path institucional)

## Objetivo

Provar o padrão **ADR-008**:

- **1 path de rede institucional** por cliente/site  
- **N operadores** só via bastion (Warpgate/Guac)  
- Operador **nunca** recebe rota/IP da LAN do cliente  

## Lab: piloto WireGuard (preferido)

Simula peer de produção **sem** dual-home do connector na LAN do site:

```
Operador → Warpgate (archgate-data)
              → platform connector (archgate-data + wg-lab)
                   ~~~ WireGuard ~~~
              → site agent (site-net + wg-lab)
                   → ssh-alvo (somente site-net)
```

| Rede | CIDR (lab) | Quem participa |
|------|------------|----------------|
| `archgate-data` | 10.0.2.0/24 | Warpgate, platform connector |
| `archgate-wg-lab` | 10.66.66.0/24 | handshake WG (simula path WAN) |
| `archgate-site-piloto` | 10.77.10.0/24 | site agent + alvo SSH |

**Invariante:** connector da plataforma **não** entra em `archgate-site-piloto`.

```bash
bash deploy/connector/deploy-wg-piloto-lab.sh
bash deploy/connector/smoke-connector-piloto.sh   # MODE=wireguard
# PASS 2026-07-10/11
```

## Lab legado: socat dual-homed

`deploy-piloto-lab.sh` ainda existe (connector em data **e** site-net via socat). Preferir WG para refletir produção.

## Produção (cliente real)

Clientes atuais usam **OpenVPN**, **WireGuard** e **openfortivpn** — todos no **connector**, não no notebook do dev.  
Detalhe: `documentos/runbooks/sites/conectividade-vpn-clientes.md`.

| Tipo ADR-008 | Stack típica | Implementação |
|--------------|--------------|---------------|
| `connector_peer` | WireGuard | Peer site ↔ connector — `wireguard-peer.example.conf` |
| `tunnel_agent` | OpenVPN / openfortivpn / agent na LAN | Cliente VPN institucional no connector (1 sessão → N operadores) |
| `vpn_user_exception` | Qualquer no notebook do dev | Exceção — `vpn-user-exceptions.md` |

Checklist: **`onboarding-cliente-peer.md`** (task 0.5).

## Scripts

| Script | Função |
|--------|--------|
| `deploy-stack.sh wireguard\|openvpn\|socat\|openfortivpn` | Dispatcher de stack |
| `deploy-wg-piloto-lab.sh` | Piloto **WireGuard** (PASS) |
| `deploy-openvpn-piloto-lab.sh` | Piloto **OpenVPN** (PASS 2026-07-11) |
| `deploy-piloto-lab.sh` | Legado socat dual-homed |
| `smoke-connector-piloto.sh` | Isolamento + path + Warpgate (`MODE=`) |
| `stacks/openvpn/` | README + systemd template produção |
| `stacks/openfortivpn/` | Scaffold Forti (sem appliance no lab) |
| `wireguard-peer.example.conf` | Template peer produção |
| `onboarding-cliente-peer.md` | Checklist cliente real |

## Limitações conscientes

- Lab WG usa overlay `archgate-wg-lab` como path de handshake (não UDP internet real).  
- Chaves lab em `/var/lib/archgate/connector/wg/` (host, fora do git).  
- NetBird control plane = tasks 1.x em `add-network-mesh`.  
- Task **0.5** (primeiro cliente real) ainda pendente de onboarding externo.  
