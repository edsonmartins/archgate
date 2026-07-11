# OpenBao — credenciais efêmeras (Fase 2, lab)

## Escopo lab (MVP)

| Feito | Pendente |
|-------|----------|
| OpenBao single-node (file storage) | HA / Raft (prod) |
| Unseal keys em `bootstrap.env` (host) | Auto-unseal KMS |
| Audit file | SIEM remoto |
| SSH CA + login cert em host lab | Warpgate nativo pedir cert SSH (upstream) |
| Database engine + **broker → Warpgate** | Plugin Vault nativo no Warpgate |

## Fluxos

### SSH CA

1. OpenBao assina certificado (`ssh/sign/lab-user`)
2. Alvo com `TrustedUserCAKeys` (lab: `archgate-lab_ssh-ca`)
3. Login com cert efêmero — **PASS** no smoke

### Postgres dinâmico + broker Warpgate

1. `broker-warpgate-db.sh issue` → `database/creds/lab-readonly`
2. Atualiza target Warpgate (`rio-lab-postgres`) com user/senha efêmeros
3. Operador: `psql` via Warpgate (`user=testuser:rio-lab-postgres`) → sessão como user dinâmico
4. `broker-warpgate-db.sh revoke` → role dropada no Postgres
5. **Systemd no runtime** (também chamado no fim de `deploy.sh` se `INSTALL_SYSTEMD=1`):  
   - `archgate-openbao-unseal.service` + **`.timer` a cada 2 min** — recupera após recreate/reboot (chave em bootstrap.env)  
   - `archgate-broker-db.timer` / `.service` — a cada **20 min** (+ 2 min após boot)  
   - targets default: `rio-lab-postgres lab-postgres marra-lab-postgres`  
   - Manual: `systemctl start archgate-openbao-unseal.service`

## Auth: OpenBao ← Kanidm (JWT)

Operadores autenticam no Kanidm (OIDC Code + PKCE); o `id_token` entra em `auth/jwt` no OpenBao.

| Peça | Valor lab |
|------|-----------|
| OAuth2 client | `openbao` (public, Kanidm) |
| Issuer | `https://id.archgate.com.br/oauth2/openid/openbao` |
| Role | `archgate-operator` → policy `archgate-operator-ephemeral` |
| Bound group | `archguard_users@id.archgate.com.br` (SPN no claim `groups`) |
| Validação | ES256 pubkey (PEM) — evita TLS discovery do container |

```bash
bash deploy/openbao/bootstrap-kanidm-auth.sh
bash deploy/openbao/smoke-kanidm-jwt.sh   # PASS: JWT login → DB dynamic + SSH CA
```

## Scripts

| Script | Função |
|--------|--------|
| `deploy.sh` | Serviço Swarm + init/unseal |
| `bootstrap-engines.sh` | SSH CA + database + policies |
| `bootstrap-kanidm-auth.sh` | OAuth2 client + `auth/jwt` + roles por grupo |
| `smoke-ephemeral.sh` | SSH cert + DB emit/revoke (token app) |
| `smoke-kanidm-jwt.sh` | OIDC Kanidm → JWT OpenBao → DB + SSH |
| `broker-warpgate-db.sh` | OpenBao → Warpgate target DB |
| `smoke-broker-warpgate.sh` | E2E operador via proxy |

## Endpoints lab

- API: `http://127.0.0.1:8200` (host publish) / `http://archgate-secrets_openbao:8200` (data)
- Tokens: `OPENBAO_ROOT_TOKEN`, `OPENBAO_APP_TOKEN` em bootstrap.env
