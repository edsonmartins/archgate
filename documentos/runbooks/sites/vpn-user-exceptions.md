# Registro de exceções `vpn_user_exception`

> Só preencher quando o cliente **obrigar** VPN de usuário no notebook.  
> Preferência: `connector_peer` / `tunnel_agent` (1 túnel → N operadores ArchGate).

## Ativas

_Nenhuma em 2026-07-10._

<!--
### Exemplo

| Campo | Valor |
|-------|--------|
| Cliente | ACME |
| Desde | 2026-xx-xx |
| Dono (IntegrAllTech) | nome@ |
| Dono (cliente) | |
| MFA na VPN | sim/não |
| Inventário hosts/portas | 10.1.2.3:22, 10.1.2.4:3389 |
| Motivo | cliente recusou peer site-to-site |
| Prazo migração para connector | 2026-xx-xx |
| Status | aberta / migrando / encerrada |
-->

## Encerradas

_Nenhuma._

## Checklist ao abrir exceção

- [ ] Aprovação comercial/segurança registrada
- [ ] Inventário fechado de hosts/portas
- [ ] MFA exigido na VPN do cliente (se disponível)
- [ ] Runbook do operador do cliente aponta só hosts inventariados
- [ ] Offboarding: revogar VPN **e** Kanidm
- [ ] Data de revisão / migração para connector
