# Onboarding — peer institucional (cliente real)

Checklist para **0.5** / produção: 1 path de rede por site, N operadores só via bastion (ADR-008).

## Pré-requisitos

- [ ] Acordo com o cliente (peer WireGuard **ou** VPN institucional OpenVPN/Forti no connector)
- [ ] Stack identificada: `wireguard` | `openvpn` | `openfortivpn` (ver `conectividade-vpn-clientes.md`)
- [ ] Subnets internas dos targets (SSH/RDP/DB) documentadas
- [ ] Ficha site em `documentos/runbooks/sites/<cliente>.yaml` com `conectividade.stack`
- [ ] Sem `vpn_user_exception` (registar se inevitável)

## Opção A — `connector_peer` (WG site ↔ plataforma)

1. No **runtime ArchGate** (ou VM connector):
   ```bash
   wg genkey | tee /var/lib/archgate/connector/<site>/platform.key | wg pubkey > .../platform.pub
   ```
2. No **edge do cliente** (firewall/VM):
   - Interface WG com `AllowedIPs` = redes de targets (só o necessário)
   - Endpoint público ou NAT hole-punch conforme política
3. Usar template `wireguard-peer.example.conf`
4. Warpgate target: `host` = IP/DNS do **connector na archgate-data** (nunca IP da LAN do cliente exposto ao operador)
5. Smoke: operador SSO → Warpgate → target; confirmar que `archgate-data` **não** alcança IP do alvo sem o peer

## Opção B — `tunnel_agent` (VPN ou agent do lado do site)

Usar quando o cliente **não** oferece peer WireGuard limpo:

| Stack do cliente | No connector ArchGate |
|------------------|------------------------|
| OpenVPN | `openvpn --config` + rotas + forward (systemd/container) |
| openfortivpn | `openfortivpn` + conta de serviço (+ 2FA alinhada com o cliente) |
| Agent na LAN | NetBird / cloudflared / WG client **dentro** da rede do cliente |

1. Deploy do cliente VPN **institucional** (1 conta) no connector — **não** no notebook do dev  
2. Encaminhar só subnets de targets  
3. Warpgate aponta para host visto pelo connector  
4. Lab análogo de path: `archgate-site-piloto_agent` (WG)  

## Opção C — `vpn_user_exception` (evitar)

VPN OpenVPN/WG/Forti no **notebook do operador**. Só com registro em `vpn-user-exceptions.md` e plano de migração para A ou B.

## Lab de referência (já validado)

```bash
bash deploy/connector/deploy-wg-piloto-lab.sh   # WireGuard real (sem dual-homed site-net)
bash deploy/connector/smoke-connector-piloto.sh # MODE=wireguard
```

Prova:

| Check | Esperado |
|-------|----------|
| Site SSH só em `archgate-site-piloto` | sim |
| Connector **sem** site-net | sim (só data + WG transport) |
| Path data → connector ~~~ WG ~~~ agent → SSH | PASS |
| Operador via Warpgate | PASS |

## Pós-onboarding

- [ ] Atualizar `sites/INVENTARIO.md` (`conectividade.tipo=connector_peer|tunnel_agent`)
- [ ] Atualizar matriz: `documentos/MATRIZ_FUNCIONALIDADES.md`
- [ ] Marcar task **0.5** em `openspec/changes/add-network-mesh/tasks.md` com o nome do cliente
