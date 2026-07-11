# Inventory — ArchGate lab/staging

Atualizado: 2026-07-10

## Hosts

| IP | Hostname | Papel | Docker | Swarm | RAM | Disco |
|---|---|---|---|---|---|---|
| `192.168.1.180` | `edson-ai` | ArchGate runtime | 28.5.1 | init aqui | 15 GiB | ~104 GiB livres |
| `192.168.1.110` | `localhost.localdomain` | Infra compartilhada | 26.1.4 | active (outro cluster) | 7 GiB | ~8 GiB livres (84%) |

## Domínio

- Base: **archgate.com.br**
- Hosts: `id`, `wg`, `guac`, `console` (subdomínios)
- Túnel Cloudflare já ativo em `.180` (`cloudflared` → config em `/etc/cloudflared/config.yml`)

## Identidade = ArchGuard (não recriar)

| Item | Valor |
|---|---|
| Repo | `/Users/edsonmartins/desenvolvimento/archguard` |
| Engines | Kanidm (`kanidmd`) + ArchGuard Console + AliasVault |
| Setup | `scripts/setup-kanidm.sh` (grupos `archguard_*`, OAuth2, SA) |
| Doc de integração | `deploy/archguard-integration.md` |

Estado atual (2026-07-10):

| Serviço | Host | Status |
|---|---|---|
| Traefik | `.180` Swarm `archgate-edge_traefik` | 1/1 |
| Kanidm 1.10.4 | `.180` `archgate-id_kanidmd` :8443 + Traefik `id.archgate.com.br` | healthy |
| ArchGuard Console | `.180` `archgate-id_archguard-console` + Traefik `console.archgate.com.br` | 1/1 |
| Warpgate 0.26.1 | `.180` `archgate-gw_warpgate` + Traefik `wg.archgate.com.br` | 1/1 (SSO Minimized) |
| Guacamole / guacd 1.6.0 | `.180` + Traefik `guac.archgate.com.br` | 1/1 (Postgres + recording) |
| lab OpenSSH | `archgate-lab_ssh` na rede `archgate-data` | 1/1 |
| Postgres apps | `.110:5434` warpgate/guacamole/archgate_lab | provisioned |

Bootstrap secrets: `/root/archgate/bootstrap.env` no `.180` (mode 600).

## PostgreSQL externo (Fase 1 / ADR-003)

| Campo | Valor |
|---|---|
| Host | `192.168.1.110` |
| Porta host | `5434` |
| Container | `root-postgres-1` (`postgres:16-alpine` / 16.10) |
| Admin role (pré-existente) | `rioquality` (superuser) |
| DB/role ArchGate | `warpgate` / `warpgate` |
| DB/role ArchGate | `guacamole` / `guacamole` |

Senhas de aplicação: apenas em bootstrap fora do git (`/root/archgate/bootstrap.env` no host `.180`).

## Cargas pré-existentes (não tocar sem necessidade)

### 192.168.1.180

- Stack **direto** (tinode, core-cliente, bridge, coturn) — portas 6060, 8090, 16060, 3478
- Ollama `:11434`, cloudflared

### 192.168.1.110

- Postgres 16 `:5434`, Timescale `:15432`, pgvector `:5444`
- Redis, MySQL, Mongo, MinIO, NATS, ActiveMQ, Evolution API, etc.
- Disco apertado — **não** gravar sessões ArchGate neste host; volumes de sessão ficam no `.180`
