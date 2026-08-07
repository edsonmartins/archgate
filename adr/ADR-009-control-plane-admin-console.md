# ADR-009 — Control plane: um console admin (estilo AWS Console)

- **Status:** Aceito (direção de produto)
- **Data:** 2026-07-11
- **Atualizado:** 2026-08-07 — ArchGate Manager definido como superfície obrigatória de toda configuração suportada
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

Toda configuração suportada do produto **deve terminar no ArchGate Manager**. UIs stock de
Warpgate, Guacamole, OpenBao, OpenFGA ou qualquer outro engine são ferramentas internas de
diagnóstico e break-glass: não constituem fluxo documentado de administração, não são
expostas ao tenant e não podem ser pré-requisito para operar o produto.

Scripts e CLI continuam permitidos para bootstrap, recuperação e automação, mas cada operação
de rotina introduzida por eles precisa de API server-side e tela correspondente no Manager
antes de ser considerada funcionalidade completa.

### 2. UnifiedUI / Connect ≠ Manager

| Superfície | Público | Função |
|------------|---------|--------|
| **ArchGate Manager** (este ADR) | Super Admin / Tenant Admin | Configurar clientes, identidade, gateways |
| **ArchGate Connect** | Operador (desktop) | Sessões embutidas (ADR-008A/B) |
| **UnifiedUI** | Operador (browser) | Abrir sessão RDP/SSH no browser, catálogo “minhas conexões” |

Não bloquear o Manager à UnifiedUI/Connect.

### 3. Padrão de segurança (inalterado)

- Tokens administrativos e senhas de alvo **nunca** no browser.
- Todo write em ArchGuard, OpenFGA, Warpgate, Guacamole e OpenBao ocorre via **BFF server-side** com sessão OIDC, autorização por ação e contrato de API explícito.
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
| **CP-7** | Mentors Axis sync + memberships ArchGuard + role Warpgate | **Parcial** — sync existente; migrar semântica antiga de grupos para memberships |
| **CP-8** | Aplicações OIDC, service accounts e políticas ArchGuard | **Pendente** — eliminar bootstrap manual do fluxo normal |
| **CP-9** | Grants OpenFGA, aprovações, step-up e break-glass | **Pendente** |
| **CP-10** | Connectors: enrollment, rotação, upgrade, diagnóstico e revogação | **Pendente** |
| **CP-11** | Configuração versionada, preview/diff, apply assíncrono e rollback | **Pendente** |
| **CP-12** | Auditoria de configuração e trilha de mudanças por recurso | **Pendente** |
| **Plataforma** | Saúde stack + endpoints + runbooks | **Feito** (lab: `/platform`) |

## Consequências

**+** Um lugar para o time configurar clientes como na AWS.  
**+** Reaproveita auth/RBAC/deploy do console.  
**−** O console deixa de ser “só identidade” — product split: **ArchGuard** (módulo) vs **ArchGate Manager** (produto admin).  
**−** Integrações gateway exigem secrets no serviço console (Swarm env).  

## Fora de escopo deste ADR

- Inferência agêntica, HA de componentes (Fase 5).  
- Substituir gravação de sessão.
- Operador abrindo RDP no Manager (isso é UnifiedUI / Connect).
