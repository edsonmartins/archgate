# Integração ArchGate ↔ ArchGuard

## Princípio

**ArchGuard** (`/Users/edsonmartins/desenvolvimento/archguard`) é o **produto de identidade** da IntegrAllTech. O ArchGate **não implementa** um segundo Kanidm nem um console de IAM paralelo.

| Camada | Sistema | Responsabilidade |
|---|---|---|
| Identidade / OIDC / RBAC / console operador | **ArchGuard** (Kanidm + Console + AliasVault) | Quem é o principal; provisionar/desabilitar; OAuth2 clients; service accounts |
| Gateway de protocolo + gravação | **ArchGate** (Warpgate + Guacamole + Traefik + malha) | Acesso privilegiado sem credencial no dev; sessões auditadas |

CONSTITUTION: *“ArchGuard é o módulo de identidade dentro do ArchGate”* — na prática isso significa **dependência de produto**, não reimplementação.

## O que o ArchGuard já entrega (reutilizar)

Repo: `~/desenvolvimento/archguard`

| Peça | Papel | Notas |
|---|---|---|
| `kanidmd` | IdP OIDC + API `/v1/` | Compose local `:8443`; prod atrás de Caddy |
| `archguard-console` | Console operador (TanStack Start) | Dual session OIDC + SA; proxy server-side com allowlist de path |
| `scripts/setup-kanidm.sh` | Bootstrap idempotente | Grupos RBAC, OAuth2 `archguard-console`, SA `archguard-sa` |
| AliasVault | Cofre de senhas humanas | **Não** substitui OpenBao (Fase 2) |

### Grupos RBAC já modelados

- `archguard_users`
- `archguard_super_admins`
- `archguard_tenant_admins`
- `archguard_service_desk`
- `archguard_viewers`

Mapeamento Fase 1 ArchGate: Super Admin / Tenant Admin / Operador / Service Desk / Viewer → estes grupos (Operador ≈ `archguard_users` + claims de tenant).

| Papel | Grupos Kanidm | Console |
|---|---|---|
| Super Admin | `archguard_super_admins` | todas as perms (`system:admin`) |
| Tenant Admin | `archguard_tenant_admins` + `tenant_{slug}` | users/groups do tenant (sem OAuth2/SA/system) |
| Operador | `archguard_users` + `tenant_{slug}` | read-only no escopo do tenant |
| Viewer | `archguard_viewers` + `tenant_{slug}` | read-only |
| Service Desk | `archguard_service_desk` | read + reset credencial |

Tenants ArchGate = grupos `tenant_rio_quality`, `tenant_grupo_marra`, … (não confundir com `{slug}_admins` legado do console). Validação: `deploy/validation/console-rbac-e2e.sh`.

### Padrão de segurança (já na CONSTITUTION)

- OIDC Authorization Code + **PKCE**
- Token administrativo (`ARCHGUARD_SA_TOKEN`) **só server-side**
- Proxy `kanidm-proxy.ts` com validação de path (anti-SSRF)

## O que o ArchGate adiciona sobre o ArchGuard

1. Registrar OAuth2 clients no **mesmo** Kanidm:
   - `warpgate` (OIDC)
   - `guacamole` (OIDC, extensão openid)
   - manter `archguard-console`
2. Mapear grupos Kanidm → RBAC de targets Warpgate/Guacamole
3. Persistência externa Warpgate/Guacamole (já no Postgres `.110`)
4. Offboarding: desabilitar pessoa no ArchGuard/Kanidm → SSO dos gateways cai

## Domínios propostos (`archgate.com.br`)

| Host | Serviço | Origem do código |
|---|---|---|
| `id.archgate.com.br` | Kanidm (issuer OIDC) | ArchGuard `kanidmd` |
| `console.archgate.com.br` | ArchGuard Console | ArchGuard `archguard-console` |
| `vault.archgate.com.br` (opcional) | AliasVault | ArchGuard |
| `wg.archgate.com.br` | Warpgate | ArchGate |
| `guac.archgate.com.br` | Guacamole | ArchGate |

TLS de borda: Traefik no `.180` e/ou Cloudflare Tunnel (já no host).

## Deploy (lab IntegrAllTech)

| Host | O que sobe |
|---|---|
| `192.168.1.180` | Stack ArchGuard (Kanidm + Console [+ Vault]) **e** stack ArchGate (Traefik, Warpgate, Guacamole) |
| `192.168.1.110` | Postgres compartilhado (Warpgate/Guacamole DBs); **não** hospedar Kanidm aqui (disco apertado) |

Opções de empacotamento:

1. **Preferida:** Swarm/compose do ArchGuard no `.180`, redes `archgate-public` / `archgate-data`; ArchGate só referencia `ARCHGUARD_ID_URL=https://id.archgate.com.br`.
2. **Futuro monorepo:** submodule ou path workspace apontando para `archguard` (sem copiar o código).

## Implicações para `add-identity-axis`

| Tarefa original | Como executar de fato |
|---|---|
| 2.x Kanidm | Deploy/config do **ArchGuard** (não inventar stack Kanidm isolada) |
| 2.5 OAuth2 clients | Estender setup ArchGuard: clients `warpgate`, `guacamole` + `archguard-console` |
| 2.3 Papéis RBAC | Reusar grupos `archguard_*` do setup; tenants como grupos/escopos adicionais |
| 5.x ArchGuard console | Deploy do `archguard-console` existente; **não** reescrever console na Fase 1 |
| 3–4 Warpgate/Guacamole | SSO → `id.archgate.com.br` (issuer Kanidm do ArchGuard) |

## Fora de escopo desta integração

- Reescrever ArchGuard Console em Mantine/Archbase (Fase 4 / ADR-006 se aplicável)
- OpenBao (Fase 2) — distinto de AliasVault
- Unificar repositórios git (pode ficar em repos separados; integração é por rede/OIDC)
