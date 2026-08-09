# ArchGate — Deploy histórico (Docker Swarm)

> Este diretório está superseded. O deploy suportado atualmente está em
> `archgate-devops`; não use estes manifests para provisionar a VPS.

Infraestrutura da Fase 1 (`add-identity-axis`). Engines são **operados e integrados**, não reescritos.

Inventário vivo: [`inventory.md`](./inventory.md).

## Topologia

| Host | Papel |
|---|---|
| `192.168.1.180` (`edson-ai`) | Swarm ArchGate, Traefik, gateways, sessões |
| `192.168.1.110` | Postgres externo (`:5434`) e demais infra legada |

Bootstrap no host ArchGate: `/root/archgate/bootstrap.env` (mode 600, fora do git).

## Versões pinadas

As versões abaixo são apenas referência histórica da topologia Swarm anterior.

| Componente | Imagem pinada |
|---|---|
| PostgreSQL (cliente/alvo) | cluster existente 16.x em `.110` |
| Traefik | `traefik:v3.4.1` |
| Warpgate | `ghcr.io/warp-tech/warpgate:v0.26.1` |
| Guacamole / guacd | `guacamole/guacamole:1.6.0` / `guacamole/guacd:1.6.0` |

## Redes e labels (host `.180`)

```bash
# Swarm single-node no ArchGate host
docker swarm init --advertise-addr 192.168.1.180

./deploy/bootstrap-networks.sh
docker node update --label-add archgate.edge=true $(docker node ls -q)
```

- `archgate-data` — backends (alcançam Postgres em `.110` via IP LAN)
- `archgate-public` — Traefik ↔ serviços HTTP
- `archgate-site-piloto` — LAN simulada de cliente (connector lab; ver `deploy/connector/`)

### Site connector (Fase 3 parcial)

Padrão **1 connector / site → N operadores via bastion** (ADR-008), sem NetBird completo:

```bash
# no runtime
bash deploy/connector/deploy-piloto-lab.sh
bash deploy/connector/smoke-connector-piloto.sh
```

Docs: [`deploy/connector/README.md`](./connector/README.md).

### OpenBao (Fase 2 lab — credenciais efêmeras)

```bash
bash deploy/openbao/deploy.sh
bash deploy/openbao/bootstrap-engines.sh
bash deploy/openbao/smoke-ephemeral.sh
```

SSH CA + Postgres dinâmico no lab. Broker DB → Warpgate:

```bash
bash deploy/openbao/broker-warpgate-db.sh issue   # empurra cred efêmera ao target
bash deploy/openbao/smoke-broker-warpgate.sh
# renovação automática no host:
bash deploy/openbao/systemd/install-timer.sh
# systemctl list-timers archgate-broker-db.timer
```

Integração SSH cert no Warpgate ainda pendente (ver `deploy/openbao/README.md`).

Não unir o Swarm de `.110` ao de `.180`: clusters separados de propósito.

## Segredos de bootstrap (tarefa 1.3)

1. Plaintext canônico no host: `/root/archgate/bootstrap.env`
2. Opcional: age + SOPS para cópia no repositório criptografada (`deploy/secrets/bootstrap.enc.env`)
3. Gerar chave age **fora** do repositório: `age-keygen -o ~/.config/archgate/age-key.txt`
4. Chave privada age **nunca** no git nem nos containers da plataforma

## PostgreSQL externo (tarefa 1.1 / ADR-003)

Reutiliza `root-postgres-1` em **192.168.1.110:5434** (não sobe stack Postgres novo neste lab).

| Database | Role | Consumidor |
|---|---|---|
| `warpgate` | `warpgate` | Warpgate |
| `guacamole` | `guacamole` | Guacamole |

Provisionamento:

```bash
set -a && source /root/archgate/bootstrap.env && set +a
./deploy/postgres/provision-external.sh
```

Validação (do host `.180`):

```bash
set -a && source /root/archgate/bootstrap.env && set +a
PGPASSWORD="$POSTGRES_WARPGATE_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U warpgate -d warpgate -c 'SELECT 1'
PGPASSWORD="$POSTGRES_GUACAMOLE_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U guacamole -d guacamole -c 'SELECT 1'
```

Stack `postgres/stack.yml` e `docker-compose.local.yml` servem para PoC isolada sem o Postgres de `.110`.

## Traefik (tarefa 1.2)

```bash
set -a && source /root/archgate/bootstrap.env && source deploy/versions.env && set +a
docker stack deploy -c deploy/traefik/stack.yml archgate-edge
```

- Let's Encrypt HTTP-01 exige DNS público + portas 80/443 alcançáveis da Internet.
- Neste lab, borda pública preferencial: **Cloudflare Tunnel** já em `/etc/cloudflared/config.yml` (adicionar hostnames `*.archgate.com.br` apontando para serviços locais).
- Volumes de sessão/gravação **sempre** no `.180` (disco do `.110` está apertado).

## Domínios

- `id.archgate.com.br` — archguard
- `wg.archgate.com.br` — Warpgate
- `guac.archgate.com.br` — Guacamole
- `console.archgate.com.br` — ArchGuard
