# Tasks — Add Network Mesh (Fase 3)

## 0. Connector institucional (parcial — sem NetBird)
- [x] 0.1 Padrão dual-network connector documentado (`deploy/connector/README.md`)
- [x] 0.2 Lab piloto: rede site isolada + connector + target Warpgate (`deploy-piloto-lab.sh` socat; **WG** em `deploy-wg-piloto-lab.sh`)
- [x] 0.3 Smoke: site fora de archgate-data; path via connector; operador via bastion (`smoke-connector-piloto.sh` PASS 2026-07-10 socat; **PASS 2026-07-11 WireGuard**)
- [x] 0.4 Template WireGuard peer produção (`wireguard-peer.example.conf`)
- [x] 0.4b Lab WireGuard real: connector **sem** site-net; tunnel agent no site (`deploy-wg-piloto-lab.sh` + smoke MODE=wireguard) — substitui socat dual-homed no lab
- [x] 0.4c Checklist onboarding cliente real (`onboarding-cliente-peer.md`)
- [x] 0.4d Lab **OpenVPN** tunnel_agent (`deploy-openvpn-piloto-lab.sh` + smoke MODE=openvpn PASS 2026-07-11)
- [x] 0.4e Scaffold **openfortivpn** + multi-stack doc (`stacks/openfortivpn/`, `conectividade-vpn-clientes.md`)
- [x] 0.4f Dispatcher `deploy-stack.sh` (wireguard|openvpn|socat|openfortivpn)
- [ ] 0.5 Primeiro cliente **real** com VPN/peer (onboarding externo; lab WG+OpenVPN validam o padrão)

## 1. NetBird — malha
- [ ] 1.1 Subir NetBird control plane (self-hosted)
- [ ] 1.2 Instalar peer na rede de um cliente-piloto
- [ ] 1.3 Instalar peer junto aos gateways (Warpgate/Guacamole)
- [ ] 1.4 Configurar segmentação por tenant (alcance de um cliente não vaza para outro)
- [ ] 1.5 Definir políticas de acesso da malha (quais peers falam com quais)

## 2. Integração Cloudflare Tunnel (Rio Quality)
- [ ] 2.1 Mapear o Tunnel existente como via de borda complementar
- [ ] 2.2 Validar coexistência malha + Tunnel sem rota conflitante

## 3. Alcance via malha
- [ ] 3.1 Validar: gateway alcança alvo do cliente-piloto através da malha
- [ ] 3.2 Confirmar: dev nunca recebe acesso direto à rede do cliente

## 4. Cobertura de protocolo
- [ ] 4.1 RDP ponta a ponta: dev abre desktop Windows real de cliente via Guacamole
- [ ] 4.2 Kubernetes via Warpgate contra cluster de cliente
- [ ] 4.3 **ADR-001 (Oracle):** decidir engine dinâmico OpenBao vs. alternativa
- [ ] 4.4 Implementar acesso Oracle conforme decisão do ADR-001

## 5. Validação de ponta a ponta
- [ ] 5.1 Matriz SSH/RDP/DB/K8s/Web funcional para o cliente-piloto
- [ ] 5.2 Isolamento entre tenants comprovado por teste
- [ ] 5.3 Sessões gravadas independentemente do protocolo
