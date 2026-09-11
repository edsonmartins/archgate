# Conectividade de site — OpenVPN, WireGuard e openfortivpn

**Contexto real (IntegrAllTech):** clientes usam hoje **OpenVPN**, **WireGuard** e **openfortivpn** (FortiGate SSL VPN).  
Isso **não** muda o modelo do operador: o notebook do dev **não** sobe a VPN do cliente no fluxo padrão (ADR-008).

```
Operador (Linux|macOS|Windows)
  → SSO ArchGate → Warpgate / Guacamole
       → [connector institucional: 1 sessão VPN/peer por site]
            → LAN / alvos do cliente
```

---

## 1. Onde cada tecnologia encaixa

| Tecnologia no cliente | Papel no ArchGate | Tipo ADR-008 típico | Onde roda o cliente VPN |
|----------------------|-------------------|---------------------|-------------------------|
| **WireGuard** | Peer site ↔ connector (ou peer na malha NetBird) | `connector_peer` (preferido) ou `tunnel_agent` | Connector na plataforma **ou** agent no edge do cliente |
| **OpenVPN** | Cliente OpenVPN **institucional** (`.ovpn` + credenciais de serviço) | `tunnel_agent` (quase sempre) | VM/container connector que **entra** na VPN do cliente |
| **openfortivpn** | Cliente Forti SSL VPN institucional | `tunnel_agent` | Mesmo: host Linux com `openfortivpn` + rotas/forwards |

**Regra:** a tecnologia VPN é **config do site** (ficha YAML / inventário), não preferência do operador.

---

## 2. Matriz de decisão (onboarding)

| Situação | Escolher | Notas |
|----------|----------|--------|
| Cliente aceita peer WireGuard dedicado ao ArchGate | `connector_peer` + WG | Melhor isolamento e operação; lab: `deploy-wg-piloto-lab.sh` |
| Cliente só entrega `.ovpn` / portal OpenVPN | `tunnel_agent` + OpenVPN client no connector | 1 conta de serviço; MFA/token se o cliente exigir — automatizar com cuidado |
| Cliente só FortiGate SSL VPN (openfortivpn) | `tunnel_agent` + openfortivpn no connector | Muitas vezes 2FA; preferir conta de serviço + aprovação do cliente |
| Cliente **proíbe** connector e exige VPN no notebook do dev | `vpn_user_exception` | Exceção documentada em `vpn-user-exceptions.md` + plano de migração |
| Já existe Cloudflare Tunnel / outro agent | `tunnel_agent` (ou coexistência — task mesh 2.x) | Não substitui SSO/bastion |

---

## 3. O que é comum aos três

1. **Uma** sessão VPN/peer por site (ou por tenant/site), não N VPNs de devs.  
2. Warpgate/Guac veem só IPs **alcançáveis pelo connector** (host interno ou VIP no connector).  
3. Operador autentica no **archguard**; offboarding desliga SSO, não “revoga 40 configs OpenVPN de notebook”.  
4. Credenciais de VPN do cliente ficam em **bootstrap/secret do connector** (fora do git), não no endpoint do dev.  
5. Multi-tenant: um connector (ou namespace de rotas) por cliente — sem rota cruzada.

---

## 4. Detalhe por stack

### 4.1 WireGuard

- **Preferido** quando o cliente permite peer institucional.  
- Lab validado: `deploy/connector/deploy-wg-piloto-lab.sh` + smoke MODE=wireguard.  
- Produção: `wireguard-peer.example.conf` + `onboarding-cliente-peer.md`.  
- Futuro: peers NetBird com a mesma semântica (`add-network-mesh` 1.x).

### 4.2 OpenVPN

- Connector sobe `openvpn --config site.ovpn` (systemd ou container `cap_net_admin`).  
- Após `tun0` up: rotas para subnets de targets; `socat`/proxy ou route no host para Warpgate.  
- Segredos: user/pass, certs, TLS-auth — em `/var/lib/archgate/connector/<site>/` (600).  
- Smoke: connector alcança IP alvo; `archgate-data` **sem** VPN não alcança.

### 4.3 openfortivpn (Forti SSL)

- Connector: `openfortivpn host:port -u svc_archgate` (ou config file).  
- Frequentemente **OTP/2FA** — alinhar com o cliente conta de serviço sem 2FA interativo, ou vault de token operacional.  
- Mesmo padrão de forward pós-túnel que OpenVPN.  
- Documentar no inventário: `conectividade.stack: openfortivpn` + versão FortiGate se conhecida.

---

## 5. Campos na ficha de site (YAML)

```yaml
conectividade:
  tipo: connector_peer | tunnel_agent | vpn_user_exception
  stack: wireguard | openvpn | openfortivpn | netbird | cloudflare_tunnel | mixed
  # Exemplos:
  # stack: openvpn
  # openvpn_profile: secrets/not-in-git/cliente.ovpn
  # stack: openfortivpn
  # forti_host: vpn.cliente.example
  # stack: wireguard
  # wg_peer: ...
  subnets_alvo: ["10.50.0.0/24"]
  connector_id: connector-<cliente>-<site>
  notas: ""
```

---

## 6. O que **não** fazer

| Anti-padrão | Por quê |
|-------------|---------|
| Cada dev com OpenVPN/WG/Forti no notebook + SSH direto | Quebra auditoria, offboarding e multi-tenant |
| Um único connector com rotas de **todos** os clientes | Risco de vazamento entre tenants |
| Guardar `.ovpn` / senha Forti no repo git | Segredo de borda |
| Misturar VPN de usuário com targets privilegiados sem registrar exceção | Shadow IT |

---

## 7. Estado lab vs. produção

| Item | Status |
|------|--------|
| Path institucional genérico (bastion → connector → site) | **Feito** (lab) |
| WireGuard peer lab | **Feito** (`deploy-wg-piloto-lab.sh` + smoke) |
| OpenVPN client lab (tunnel_agent) | **Feito** (`deploy-openvpn-piloto-lab.sh` + smoke PASS 2026-07-11) |
| Template/checklist WG + units produção | **Feito** |
| Unit/systemd OpenVPN produção (`stacks/openvpn/systemd`) | **Feito** (template) |
| Connector openfortivpn lab E2E | **Pendente** (sem FortiGate no lab; scaffold em `stacks/openfortivpn/`) |
| NetBird unificando peers | **Pendente** (Fase 3) |
| Inventário por cliente com `stack:` preenchido | **Pendente** (preencher em `INVENTARIO.md` / YAML) |

---

## 8. Referências

- ADR-008 — cliente operador + VPN no site  
- `deploy/connector/README.md` — piloto lab  
- `deploy/connector/onboarding-cliente-peer.md` — checklist 0.5  
- `documentos/runbooks/sites/network-mesh-mapping.md` — tipo → implementação  
- `documentos/runbooks/sites/vpn-user-exceptions.md` — exceções  
- `documentos/MATRIZ_FUNCIONALIDADES.md` — feito × falta  
