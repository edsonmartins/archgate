# Warpgate MySQL bastion (F15)

Connect embute `mysql` CLI contra o proxy MySQL do Warpgate (`operator:target`), igual ao Postgres.

## Estado Hostinger (2026-07-26)

| Item | Valor |
|------|--------|
| Warpgate | `mysql.enable: **true**` (ativado 2026-07-26) |
| Listen | `[::]:33306` publicado no host |
| UFW | `33306/tcp` allow |
| Lab target | `lab-mysql` → `archgate-lab-mysql:3306` |
| Site SoT | `rio_quality_lab` + protocol `mysql` |
| PG | `55432` (ativo) |
| SSH | `2222` (ativo) |

Greeting público esperado: `8.0.3-Warpgate` no TCP `:33306`.

### Compatibilidade auth do alvo

| Backend | Warpgate 0.26 |
|---------|----------------|
| MySQL 8.0 + `mysql_native_password` | **OK** (lab) |
| MySQL 8.4 `caching_sha2_password` | **Falha** handshake alvo (error 1251) |

Lab: container `mysql:8.0` com `--default-authentication-plugin=mysql_native_password`.

Cliente operador:

```bash
mysql -h HOST -P 33306 -u 'OPERADOR:lab-mysql' -p \
  --ssl-mode=REQUIRED --enable-cleartext-plugin
```

## Ativar no VPS

1. Em `warpgate.yaml` (container `/data/warpgate.yaml`):

```yaml
mysql:
  enable: true
  listen: '[::]:33306'
  advertised_version: 8.0.3-Warpgate
```

2. Publicar porta no compose/docker:

```yaml
ports:
  - "33306:33306"
```

3. Firewall:

```bash
ufw allow 33306/tcp comment 'archgate-warpgate-mysql'
```

4. Reiniciar `archgate-warpgate`.

5. Criar target MySQL no Warpgate + grant ao role do operador.

6. Site SoT: target com `"protocolo": "mysql"`, `"engine": "warpgate"`.

## Connect

```bash
archgate db <target-mysql> --json
# → program=mysql, port=33306, username=OPERATOR:target

# Desktop: abre aba DB → PTY mysql (precisa do cliente mysql no PATH)
# Copiar: ⌘C no item do catálogo → linha mysql CLI
```

Env override:

| Variável | Default |
|----------|---------|
| `ARCHGATE_WG_MYSQL_HOST` | mesmo host SSH/PG |
| `ARCHGATE_WG_MYSQL_PORT` | `33306` |
