# Smoke F15 — Warpgate MySQL bastion + Connect

| Campo | Valor |
|-------|--------|
| Data | 2026-07-26 |
| Host | Hostinger `217.196.60.108` |

## Bastion

| Item | Resultado |
|------|-----------|
| `mysql.enable` | **true** |
| Listen | `[::]:33306` |
| Docker ports | `2222`, `55432`, `33306` |
| UFW | `33306/tcp` allow |
| Log Warpgate | `Accepting MySQL connections on [::]:33306` |
| Greeting | `8.0.3-Warpgate` (TCP handshake) |

## Lab target

| Item | Valor |
|------|--------|
| Container | `archgate-lab-mysql` (MySQL 8.4, rede `linktor-internal`) |
| WG target | `lab-mysql` kind=`mysql` → host `archgate-lab-mysql:3306` |
| Roles | `tenant-rio-quality`, `archgate-operators` |
| Site SoT | `rio_quality_lab` + `protocolo: mysql` |
| Secret ops | `/root/archgate/lab-mysql.env` (chmod 600) |

## BFF / catalog

| Check | Status |
|-------|--------|
| `GET …/connections` lab-mysql | **PASS** `protocol=mysql` engine=warpgate |
| `POST …/sessions` lab-mysql | **PASS** launch warpgate (não Guac) |
| Protocol map fix | mysql não cai mais como `ssh` |

## Connect client

Já implementado em `eda4fcd`: CLI `archgate db lab-mysql --json` → `program=mysql` port 33306; PTY embutido.

## Comando operador

```bash
mysql -h 217.196.60.108 -P 33306 -u 'OPERADOR:lab-mysql' -p --ssl-mode=REQUIRED
# senha = credencial Warpgate do operador
```

Desktop: Connect → `lab-mysql` → aba DB (requer `mysql` CLI no PATH do Mac).

## Critério F15

| Check | Status |
|-------|--------|
| Cliente MySQL embutido | **PASS** (código) |
| Bastion WG MySQL on | **PASS** |
| Target + catálogo | **PASS** |
| Sessão SQL autenticada E2E | **PASS** (2026-07-26) |

### E2E (Mac → WG:33306 → lab-mysql)

```text
mysql -h 217.196.60.108 -P 33306 -u 'uat-op-a:lab-mysql' -p \
  --ssl-mode=REQUIRED --enable-cleartext-plugin \
  -e "SELECT 1; SELECT USER();"
→ ok=1, USER=archgate_lab@172.19.0.17
→ MYSQL_E2E_PASS
```

Notas:
- Warpgate autenticou o operador (`UserAuthenticated` uat-op-a).
- Alvo lab usa **MySQL 8.0** + `mysql_native_password` (WG 0.26 não faz handshake `caching_sha2` do 8.4).
- Client precisa `--enable-cleartext-plugin` (auth `mysql_clear_password` no proxy).
