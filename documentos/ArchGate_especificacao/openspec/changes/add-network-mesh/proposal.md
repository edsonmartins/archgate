# Proposal — Add Network Mesh (Fase 3)

## Why

As Fases 1 e 2 estabelecem identidade e credenciais efêmeras, mas assumem que o gateway já **alcança** o alvo. Na prática, cada cliente tem sua própria rede, e hoje isso é resolvido com um emaranhado de VPNs avulsas. Esta fase substitui esse emaranhado por uma **malha WireGuard central (NetBird)** e fecha a **cobertura de protocolo** contra redes reais de clientes (RDP em Windows, Kubernetes e a resolução do acesso Oracle).

## What Changes

- **NetBird** como malha WireGuard: peers nas redes dos clientes, controle de acesso central, segmentação por tenant.
- Onde já existe **Cloudflare Tunnel + Zero Trust** (Rio Quality), integra-se como via de borda complementar.
- O gateway passa a alcançar os alvos **através da malha**; o dev nunca toca a rede diretamente.
- **RDP** validado ponta a ponta contra host Windows real de cliente; **Kubernetes** via Warpgate.
- **Oracle** resolvido conforme **ADR-001** (engine dinâmico do OpenBao vs. alternativa).

## Impact

- **Nova capability:** `network-reachability`.
- **Capability modificada:** `ephemeral-credentials` (adiciona credencial dinâmica Oracle, pendente ADR-001).
- **Componentes:** NetBird (control plane + peers), Cloudflare Tunnel (integração), Warpgate/Guacamole (alcance via malha).
- **Depende de:** Fases 1 e 2.
- **Fora de escopo:** UnifiedUI (Fase 4), agêntico (Fase 5).
- **Decisão bloqueadora:** ADR-001 (Oracle) precisa ser fechado nesta fase.
