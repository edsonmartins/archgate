# Runbook — Onboarding de cliente (site / conectividade + targets)

> **ADR:** [ADR-008](../../adr/ADR-008-cliente-operador-hibrido-multi-os.md)  
> **Objetivo:** cadastrar um cliente de ponta a ponta para o time remoto operar **sem** VPN full no notebook (modelo preferido).

## Visão

```
Config do cliente ACME
├── 1. Identidade (tenant / grupos Kanidm)
├── 2. Conectividade (VPN/túnel/connector)     ← "como o bastion chega lá"
├── 3. Targets (SSH, DB, RDP, HTTPS…)
├── 4. Credenciais (somente no gateway)
└── 5. Autorização (roles → targets)
```

Operadores usam [runbook cliente operador](./cliente-operador-multi-os.md).

## 1. Identidade

- [ ] Grupo tenant no Kanidm: `tenant_<slug>` (ex. `tenant_rio_quality`)
- [ ] Operadores no grupo do tenant + `archguard_users` (ou papel adequado)
- [ ] Tenant admins (se houver): `archguard_tenant_admins` + membership no tenant
- [ ] Roles Warpgate alinhadas (ex. `tenant-rio-quality`) e SSO mapping Kanidm → role

## 2. Conectividade (obrigatório na ficha do cliente)

### Preferência contratual (padrão ArchGate)

- **Default em todo contrato novo:** `connector_peer` ou `tunnel_agent` — **uma** conectividade institucional, **N** operadores via SSO ArchGate.
- **Não** distribuir conta VPN de usuário do cliente para o time remoto.
- Atualizar [sites/INVENTARIO.md](./sites/INVENTARIO.md) e, se exceção, [sites/vpn-user-exceptions.md](./sites/vpn-user-exceptions.md).

Escolher **um** tipo e a **stack** do cliente (OpenVPN / WireGuard / openfortivpn / …) e registrar:

| Tipo | Código | Quando usar | Quem autentica a VPN |
|------|--------|-------------|----------------------|
| Peer / site-to-site / WG permanente | `connector_peer` | Cliente aceita túnel institucional | Plataforma (connector) |
| Agent no site (OpenVPN/Forti client, NetBird, cloudflared) | `tunnel_agent` | Cliente entrega VPN legada ou agent | Plataforma |
| VPN de usuário no notebook | `vpn_user_exception` | Contrato **proíbe** connector | Operador (exceção) |

| Stack do cliente | Campo `conectividade.stack` | Artefato connector |
|------------------|----------------------------|--------------------|
| WireGuard | `wireguard` | peer lab/prod |
| OpenVPN | `openvpn` | `stacks/openvpn/` |
| Forti SSL (openfortivpn) | `openfortivpn` | `stacks/openfortivpn/` |

Inventário produção: [sites/clientes-reais-por-stack.md](./sites/clientes-reais-por-stack.md) · ficha [sites/cliente-site.template.yaml](./sites/cliente-site.template.yaml).

### Preferido: `connector_peer` ou `tunnel_agent`

- [ ] Uma conta/túnel VPN **institucional** (ou peer)
- [ ] Connector alcança apenas subnets/hosts necessários (least privilege)
- [ ] ArchGate (Warpgate/Guac/guacd) roteia targets via esse path
- [ ] N operadores SSO → **1** path de rede
- [ ] Documentar IP de saída visto pelo cliente (peer) para allowlist deles

### Exceção: `vpn_user_exception`

- [ ] Aprovação registrada (comercial / segurança)
- [ ] Inventário fechado de hosts/portas
- [ ] MFA exigido na VPN do cliente
- [ ] Proibido varrer rede; só targets listados
- [ ] Plano e prazo de migração para connector
- [ ] Offboarding: revogar VPN **e** Kanidm/bastion

## 3. Targets

Para cada serviço que o time precisa:

| Tipo | Engine | Exemplo de nome | Notas |
|------|--------|-----------------|-------|
| SSH | Warpgate | `acme-app-ssh` | Host = IP **interno** visto pelo connector |
| PostgreSQL / MySQL | Warpgate | `acme-pg-prod` | Credencial DB só no Warpgate |
| HTTPS admin | Warpgate | `acme-panel` | Se painel interno |
| RDP / VNC / SSH web | Guacamole | `acme-win-erp` | Browser-first (ADR-008) |

Checklist por target:

- [ ] Nome estável e legível
- [ ] Host/porta alcançáveis **do** connector (testar com `nc`/curl do host runtime)
- [ ] Credencial armazenada no gateway (não no ticket do dev)
- [ ] Role(s) que podem usar
- [ ] Gravação habilitada onde o engine suportar
- [ ] Smoke test com usuário de lab do tenant

## 4. Credenciais

- [ ] Contas técnicas de alvo com least privilege
- [ ] Rotação definida (manual Fase 1; OpenBao Fase 2+)
- [ ] Break-glass documentado e raro
- [ ] Nenhum secret no repositório git / chat

## 5. Autorização e validação

- [ ] Usuário do tenant A **não** vê targets do tenant B (isolamento)
- [ ] Operador sem role do target recebe negação clara
- [ ] Offboarding: disable no Kanidm; remover roles; (Guac local se ainda JDBC)
- [ ] Teste multi-OS do **operador** (Linux **ou** macOS **ou** Windows basta no smoke; ideal um de cada no lab genérico)

## 5b. Guacamole 1:1 + multi-tenant (browser / Parte A)

Após identities no Kanidm (grupo `archguard_users` + tenant):

```bash
# no runtime — users + conexões por tenant + ACLs
bash /root/archgate/repo/deploy/guacamole/provision-kanidm-users.sh
# DRY_RUN=1 bash .../provision-kanidm-users.sh
```

| Conexão Guac | Quem vê |
|--------------|---------|
| `rio-lab-ssh-browser` | membros `tenant_rio_quality` |
| `marra-lab-ssh-browser` | membros `tenant_grupo_marra` |
| `lab-ssh-browser` | só `archguard_super_admins` |

- Username Guac = short name Kanidm (`preferred_username`)  
- Header-auth via oauth2-proxy (ADR-007A)  
- Reexecutar o sync após onboard/offboard  
- PATCH de permissão: `remove` **exige** `"value":"READ"` (senão HTTP 500)

## 6. Entrega ao time

- [ ] Nome do tenant e targets publicados no runbook interno / wiki
- [ ] Link para [cliente-operador-multi-os](./cliente-operador-multi-os.md)
- [ ] Tipo de conectividade visível (“vocês **não** precisam da VPN ACME no PC” **ou** “exceção: VPN user, ver anexo”)
- [ ] Contato escalação se target cair (rede do site vs bastion)

## Ficha mínima (copiar por cliente)

```yaml
cliente: ACME
slug: acme
tenant_group: tenant_acme
conectividade:
  tipo: connector_peer   # connector_peer | tunnel_agent | vpn_user_exception
  notas: "WG peer 192.0.2.10; rotas 10.50.0.0/24"
targets:
  - nome: acme-app-ssh
    engine: warpgate
    protocolo: ssh
    host: 10.50.0.12
    port: 22
    roles: [tenant-acme]
  - nome: acme-pg-prod
    engine: warpgate
    protocolo: postgres
    host: 10.50.0.20
    port: 5432
    roles: [tenant-acme-dba]
  - nome: acme-win-erp
    engine: guacamole
    protocolo: rdp
    host: 10.50.0.30
    port: 3389
    roles: [tenant-acme]
validado_em:
  ssh_linux_operador: false
  ssh_macos_operador: false
  ssh_windows_operador: false
  db_proxy: false
  rdp_browser: false
```

## Relação com fases do produto

| Item | Fase / nota |
|------|-------------|
| Warpgate SSH + DB + roles | Fase 1 (identity axis) |
| Guacamole RDP/SSH web | Fase 1 (SSO Guac = ADR-007) |
| Connector / mesh (NetBird etc.) | Fase rede |
| Catálogo único + embed | Fase 4 UnifiedUI (ADR-006) |
