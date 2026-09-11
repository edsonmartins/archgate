# Inventário live — serviços e endpoints

Atualizar após mudanças de DNS/stack. Template W1-OPS08.

## Hosts

| Papel | Host | Notas |
|-------|------|-------|
| Runtime Swarm | `192.168.1.180` (`edson-ai`) | Traefik, archguard, WG, Guac, console, OpenBao |
| Postgres externo | `192.168.1.110:5434` | DBs `warpgate`, `guacamole`, `archguard_console` |

## Serviços Swarm (core)

```bash
docker service ls --format 'table {{.Name}}\t{{.Replicas}}\t{{.Image}}' | grep archgate
```

| Serviço | Porta interna / notes |
|---------|------------------------|
| `archgate-edge_traefik` | 80/443 |
| `archgate-id_archguardd` | 8443 |
| `archgate-id_archguard-console` | 3000 |
| `archgate-gw_warpgate` | HTTPS + 2222 + 55432 |
| `archgate-gw_guacamole` / `oauth2-proxy` | 8080 via proxy |
| `archgate-secrets_openbao` | 8200 |
| `archgate-axis-spring` | 9030/9031 |

## Endpoints públicos

Ver [`endpoints-staging.md`](./endpoints-staging.md).

## Timers host

| Timer | Função |
|-------|--------|
| `archgate-openbao-unseal.timer` | Unseal periódico |
| `archgate-broker-db.timer` | Broker credenciais PG → WG |
| `archgate-pg-backup.timer` | Dump PG diário |
| `archgate-recordings-backup.timer` | Recordings + sqlite |
| `archgate-openbao-audit-export.timer` | Export audit OpenBao |

## Última revisão

| Campo | Valor |
|-------|--------|
| Data | 2026-07-17 |
| Revisor | |
