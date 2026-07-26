# ADR-009 — Control plane: um console admin (estilo AWS Console)

- **Status:** Aceito (direção de produto)
- **Data:** 2026-07-11
- **Atualizado:** 2026-07-20 — nome de produto **ArchGate Manager** ([ADR-009A](./ADR-009A-archgate-manager-produto.md))
- **Relacionado:** ADR-005 (ArchGate), ADR-006 (frontend), ADR-008 (operador), UnifiedUI (Fase 4), [ADR-009A](./ADR-009A-archgate-manager-produto.md)

## Contexto

Hoje a configuração da plataforma está **espalhada**:

| Domínio | Onde se configura hoje |
|---------|------------------------|
| Identidade (pessoas, grupos, OAuth2) | ArchGuard Console |
| Targets SSH/DB | Warpgate admin stock + scripts |
| Conexões browser | Guacamole admin + scripts |
| Sites / VPN stack | YAML + inventário + `/sites` (MVP) |
| Credenciais efêmeras | OpenBao CLI/scripts |
| Connector VPN | bash/systemd no host |

O operador e o admin de plataforma **precisam** de um único painel — análogo à **AWS Console** — onde **todas** as configurações de um cliente (tenant, conectividade, targets, estado) e da plataforma sejam feitas **visualmente**, sem depender de SSH no host para o fluxo normal.

## Decisão

### 1. Console único de **admin de plataforma** = **ArchGate Manager**

Reutilizar o console em `console.archgate.com.br` (auth OIDC, RBAC, proxy server-side, UI Shadcn) como **ArchGate Manager** (control plane; ver [ADR-009A](./ADR-009A-archgate-manager-produto.md)), com navegação em módulos (como “serviços” na AWS):

| Módulo | Escopo |
|--------|--------|
| **Identidade** | Pessoas, grupos, SA, OAuth2, Vault, auditoria (já existe) |
| **Clientes / Sites** | Ficha do cliente, stack VPN, connector, targets inventário |
| **Acesso (gateways)** | Targets Warpgate, roles, (depois) conexões Guacamole |
| **Segredos** | Leases/policies OpenBao (visão admin; emissão operacional depois) |
| **Contas da org** | Inventário + checkout de contas IntegrAllTech (GCP/Play/Apple/produtos) — ver [ADR-013](./ADR-013-org-credential-broker.md) |
| **Plataforma** | Saúde dos serviços, links de runbook, estado de deploy (`/platform`) |

UIs stock Warpgate/Guacamole/OpenBao **permanecem** como “console avançado do componente” (como usar a API AWS diretamente), **não** como fluxo principal de configuração.

### 2. UnifiedUI / Connect ≠ Manager

| Superfície | Público | Função |
|------------|---------|--------|
| **ArchGate Manager** (este ADR) | Super Admin / Tenant Admin | Configurar clientes, identidade, gateways |
| **ArchGate Connect** | Operador (desktop) | Sessões embutidas (ADR-008A/B) |
| **UnifiedUI** | Operador (browser) | Abrir sessão RDP/SSH no browser, catálogo “minhas conexões” |

Não bloquear o Manager à UnifiedUI/Connect.

### 3. Padrão de segurança (inalterado)

- Tokens administrativos e senhas de alvo **nunca** no browser.
- Todo write em Warpgate/Kanidm/OpenBao via **proxy server-side** com sessão OIDC + allowlist de path.
- Segredos de VPN (`.ovpn`, Forti password, WG keys) **não** são colados no formulário; só **referências** (`secret_ref`, path no host) e deploy do connector continua controlado.

### 4. Modelo de dados do “cliente”

Fonte canônica operacional no control plane:

- **SoT preferido:** PostgreSQL (`CONSOLE_DATABASE_URL` → DB `archguard_console`).
- **Fallback lab:** SQLite em volume (`ARCHGUARD_DB_PATH` / bind `/app/data`).

```
Site (cliente)
  ├── identidade: tenant_group, roles
  ├── conectividade: tipo, stack, connector_id, subnets, meta
  ├── targets[]: engine, host, port, roles, secret_ref
  └── estado: inventariado, connector_deployed, smoke
```

Apply no gateway: botão **“Sincronizar gateways”** materializa targets **Warpgate** e conexões **Guacamole** conforme `engine` do target.

### 5. Fases de entrega

| Fase | Entrega | Status |
|------|---------|--------|
| **CP-0** | Sites CRUD + stack VPN visual | **Feito** (lab) |
| **CP-1** | Proxy Warpgate + apply targets a partir do site | **Feito** (lab; + Guacamole no apply) |
| **CP-2** | Módulo Gateways (CRUD roles + targets Warpgate) | **Feito** (lab; listagem filtrada por tenant) |
| **CP-3** | Guacamole connections proxy (list/create/delete) | **Feito** (lab) |
| **CP-4** | OpenBao: status, engines, JWT, leases, unseal | **Feito** (lab; visão admin, não emissão diária completa) |
| **CP-5** | Connector: checklist + probes + comandos deploy | **Parcial** — checklist/probes/hints; **não** executa deploy no host |
| **CP-6** | YAML + audit; SoT **PostgreSQL** + fallback SQLite | **Feito** (lab: PG `192.168.1.110`) |
| **CP-7** | Mentors Axis sync + Kanidm `tenant_*` + role Warpgate | **Feito** (lab: Spring `archgate-axis-spring`; stub desligado) |
| **Plataforma** | Saúde stack + endpoints + runbooks | **Feito** (lab: `/platform`) |

## Consequências

**+** Um lugar para o time configurar clientes como na AWS.  
**+** Reaproveita auth/RBAC/deploy do console.  
**−** O console deixa de ser “só identidade” — product split: **ArchGuard** (módulo) vs **ArchGate Manager** (produto admin).  
**−** Integrações gateway exigem secrets no serviço console (Swarm env).  

## Fora de escopo deste ADR

- Inferência agêntica, HA de componentes (Fase 5).  
- Substituir Kanidm UI interna; substituir gravação de sessão.  
- Operador abrindo RDP no Manager (isso é UnifiedUI / Connect).
