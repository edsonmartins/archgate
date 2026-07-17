# Cloudflare Tunnel + connector de site (W2-SITE07)

## Papéis distintos

| Componente | Serve para | Não substitui |
|------------|------------|----------------|
| **Cloudflare Tunnel** (borda) | Expor `*.archgate.com.br` (id, console, wg, guac) à internet de forma controlada | Acesso à **LAN do cliente** |
| **Connector de site** | Alcançar hosts SSH/DB/RDP **dentro** da rede do cliente | Publicação de UI ArchGate |

## Coexistência

```text
Internet ── CF Tunnel ──► Traefik (edson-ai) ──► console / id / wg UI / guac
                                                      │
Operador ── SSH/PG ──► Warpgate (:2222/:55432) ───────┤
                                                      ▼
                                              connector site ~~~ VPN/peer ~~~ LAN cliente
```

1. Tunnel (ou Traefik+LE) continua na **borda ArchGate**.  
2. Cada site real adiciona **connector** (WG/OpenVPN/Forti) — path data plane.  
3. Se o cliente **já** tem Cloudflare Tunnel só para apps HTTP, isso **não** implica path SSH/DB: ainda precisa connector ou Tunnel com private network routing **explícito** e inventariado.

## Rio Quality (hipótese)

Arquitetura cita Tunnel existente. Na ficha `reais/rio-quality.yaml`:

- Confirmar se o Tunnel cobre **só HTTP de borda** ou também **redes privadas**.  
- Se só HTTP: stack de bastion = connector WG/OpenVPN/Forti separado.  
- Se private network CF: documentar CIDRs e como o Warpgate (no runtime) alcança o next-hop.

## Checklist

- [ ] Diagrama do site: Tunnel vs connector  
- [ ] Nenhum overlap de rota confuso entre CF WARP e connector  
- [ ] Smoke bastion → alvo **sem** VPN no notebook  
