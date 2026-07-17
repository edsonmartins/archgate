# Segmentação de rede por tenant (W2-SITE06)

## Invariantes

1. **Operador** nunca recebe rota/IP da LAN do cliente (ADR-008).  
2. **1 connector institucional / site** — não compartilhar connector entre tenants.  
3. **Warpgate roles** e **Guac ACLs** isolam o que o operador *vê*; a rede reforça o que o *connector alcança*.  
4. Connector da plataforma **não** se dual-home na LAN do site (lab WG: connector só em `archgate-data` + transport WG).

## Camadas

```text
                    ┌─ tenant A role ── targets A
Operador ─ SSO ──► Bastion
                    └─ tenant B role ── targets B   (sem overlap de nomes)

Connector site A ── só subnets A ── hosts A
Connector site B ── só subnets B ── hosts B
```

| Camada | Mecanismo |
|--------|-----------|
| Identidade | grupos Kanidm `tenant_*` |
| Bastion | roles Warpgate / perms Guac |
| Rede | AllowedIPs / rotas OpenVPN **mínimas** por site |
| Admin | SoT sites + deny-by-default console |

## Checklist onboarding

- [ ] `connector_id` único por site  
- [ ] Subnets só as dos targets inventariados  
- [ ] Nenhum `AllowedIPs = 0.0.0.0/0` em produção  
- [ ] Smoke: operador A **não** conecta target B  
- [ ] Smoke: do connector A, **não** há rota para subnets B  

## Anti-padrões

| Evitar | Por quê |
|--------|---------|
| Um peer “hub” com todas as LANs de clientes | Blast radius e falha de isolamento |
| Publicar IP do alvo no runbook do dev | Quebra zero-credencial / anti-padrão |
| VPN user no notebook “só um pouquinho” | Exceção — registrar e migrar |
