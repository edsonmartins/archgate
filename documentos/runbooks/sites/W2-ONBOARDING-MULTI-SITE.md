# W2 — Onboarding multi-site (playbook)

Ordem para N sites reais sem NetBird (ADR-010).

## Por site

1. **Inventário** — linha em `clientes-reais-por-stack.md` + ficha `reais/<slug>.yaml`.  
2. **Stack** — `wireguard` | `openvpn` | `openfortivpn` | `mixed` | `cloudflare_tunnel`.  
3. **Tipo** — `connector_peer` ou `tunnel_agent` (evitar `vpn_user_exception`).  
4. **Peer/VPN** — `deploy/connector/onboarding-cliente-peer.md`.  
5. **Targets** — host/port internos; secrets `TARGET_SECRET_*` / OpenBao.  
6. **Apply** Warpgate + Guac (ACL tenant).  
7. **Kanidm** — grupo `tenant_<slug>` + membros.  
8. **Matriz protocolos** — atualizar `matriz-protocolos.md`.  
9. **Smoke** — operador do tenant: SSH e/ou PG; isolamento cruzado.  
10. **Evidência** — `smoke-evidence-YYYY-MM-DD-<slug>.md`.

## Ordem de clientes sugerida

| Ordem | Site | Motivo |
|------:|------|--------|
| 1 | Rio Quality prod | Piloto homologação (W0-B) |
| 2 | Grupo Marra prod | 2º tenant já modelado no lab |
| 3+ | Axis SoT (`aj_rorato`, …) | Após stack confirmada |

## Lab multi-tenant (já existe)

| Tenant | Lab path | Isolamento |
|--------|----------|------------|
| Rio | `rio-lab-*` | role `tenant-rio-quality` |
| Marra | `marra-lab-*` | role `tenant-grupo-marra` |
| Piloto connector | `piloto-lab-ssh` | path WG site isolado |

Usar lab para treinar ops **antes** do peer real.
