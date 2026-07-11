# Runbook — Cliente operador (Linux / macOS / Windows)

> **ADR:** [ADR-008](../../adr/ADR-008-cliente-operador-hibrido-multi-os.md)  
> **Escopo:** notebook do **operador** (não o SO do servidor alvo — alvos são tipicamente Linux).

## Princípio

Acesso privilegiado **sempre** pelo bastion ArchGate.  
Credenciais de VPS/banco/Windows do cliente **não** ficam no seu laptop.

```
Você (Linux | macOS | Windows)
  → ArchGate (SSO / bastion)
  → rede do cliente (VPN/túnel no connector — transparente para você)
  → alvo
```

## URLs e portas (staging / lab)

| Serviço | Uso | Endpoint |
|---------|-----|----------|
| Console identidade | Gestão IAM (ArchGuard) | `https://console.archgate.com.br` |
| Warpgate (admin / web) | Targets SSH/DB/HTTP | `https://wg.archgate.com.br` |
| Warpgate SSH | Cliente OpenSSH | `wg.archgate.com.br:2222` (ou IP/host interno conforme deploy) |
| Warpgate Postgres | Cliente SQL | porta publicada do serviço (ex. `55432` no host runtime) |
| Guacamole | RDP / SSH / VNC no **browser** | `https://guac.archgate.com.br` |
| Identidade (OIDC) | Login Kanidm | `https://id.archgate.com.br` |

Valores de lab podem usar `127.0.0.1` + Host header no host Swarm; operadores remotos usam os hostnames públicos/CF.

## Parte A — Browser (clientless)

**Oficial:** Chrome ou Firefox atual; Edge no Windows ok.

| Ação | Onde |
|------|------|
| Gestão de identidades / grupos | Console ArchGuard (SSO Kanidm) |
| RDP / desktop remoto | Guacamole → conexão autorizada |
| SSH no browser | Guacamole (SSH web) ou UI Warpgate |
| Painéis HTTP internos | Via target HTTP no Warpgate, quando cadastrado |

**RDP:** preferir sempre o browser (paridade Linux/macOS/Windows).

### Guacamole (ADR-007 / ADR-007A)

1. Abrir `https://guac.archgate.com.br` → **SSO Kanidm** (oauth2-proxy, Code+PKCE).
2. Happy path: identidade vira user Guacamole (`preferred_username` = user JDBC 1:1) via header — **sem segundo login**.
3. Break-glass: `guacadmin` só equipe plataforma.
4. Use só conexões liberadas; não reutilize senha de alvo.

Validação portão: `deploy/validation/guacamole-sso-proxy-e2e.sh`  

Sync automático de operadores (membros Kanidm `archguard_users` → Guacamole):

```bash
bash deploy/guacamole/provision-kanidm-users.sh
# DRY_RUN=1 bash deploy/guacamole/provision-kanidm-users.sh
```

## Parte B — Desktop via bastion

### Clientes oficiais suportados (congelado — ADR-008 P1)

| Protocolo | Software **oficial** | Versão mínima | Linux | macOS | Windows |
|-----------|----------------------|---------------|:-----:|:-----:|:-------:|
| Browser (Parte A) | **Chrome** ou **Firefox** (Edge ok no Windows) | atual / ESR | ✓ | ✓ | ✓ |
| SSH | **OpenSSH** (`ssh`) | 8.0+ | ✓ | ✓ | ✓ (Optional Feature) |
| PostgreSQL / MySQL | **DBeaver Community** **ou** CLI `psql` / `mysql` | DBeaver 23+ | ✓ | ✓ | ✓ |

- **Não exigido:** app desktop proprietário ArchGate, PuTTY (opcional no Windows), agente no notebook.
- **Best-effort:** DataGrip, Azure Data Studio, Terminal alternativos — desde que usem o mesmo host/porta/user do bastion.
- Snippets versionados: [`snippets/ssh-warpgate.example`](./snippets/ssh-warpgate.example), [`snippets/dbeaver-warpgate-postgres.example`](./snippets/dbeaver-warpgate-postgres.example).
- Endpoints lab: [`endpoints-staging.md`](./endpoints-staging.md).
- Inventário de sites / conectividade: [`sites/INVENTARIO.md`](./sites/INVENTARIO.md).
- Smoke: `deploy/validation/smoke-operator-access.sh` · evidência [`sites/smoke-evidence-2026-07-10.md`](./sites/smoke-evidence-2026-07-10.md).

### SSH via Warpgate (mesmo comando nos três SO)

```bash
ssh -p 2222 'SEU_USUARIO:NOME_DO_TARGET@wg.archgate.com.br'
```

Exemplo lab (host runtime):

```bash
ssh -p 2222 'testuser:rio-lab-ssh@192.168.1.180'
# ou, com DNS:
# ssh -p 2222 'testuser:rio-lab-ssh@wg.archgate.com.br'
```

Smoke automatizado (runtime ou notebook com rede ao bastion):

```bash
bash deploy/validation/smoke-operator-access.sh
```

Autenticação: identidade ArchGate / Warpgate (SSO ou credencial de operador conforme configuração atual) — **não** a senha `root`/`labuser` do alvo.

#### `~/.ssh/config` (opcional, idêntico em Linux/macOS/Windows OpenSSH)

```sshconfig
Host archgate-wg
  HostName wg.archgate.com.br
  Port 2222
  # User preenchido por conexão: use ssh archgate-wg com
  # User SEU_USUARIO:NOME_DO_TARGET  ou a forma user@host acima
```

Uso típico continua com `usuario:target@host` na linha de comando (sintaxe Warpgate).

### Banco via Warpgate

1. Host = endpoint Warpgate (`wg…` ou `192.168.1.180` no lab) — **não** o IP interno do Postgres.
2. Port = **55432** (proxy Postgres do Warpgate no lab).
3. Username = `OPERADOR:TARGET` (ex. `testuser:rio-lab-postgres`).
4. Password = senha do **operador no Warpgate**.
5. SSL mode = **require** (obrigatório no proxy, mesmo se o alvo interno for sem TLS).

CLI:

```bash
PGPASSWORD='***' psql \
  'host=192.168.1.180 port=55432 user=testuser:rio-lab-postgres dbname=archgate_lab sslmode=require' \
  -c 'select current_user, 1 as ok;'
```

Detalhes DBeaver/JDBC: [`snippets/dbeaver-warpgate-postgres.example`](./snippets/dbeaver-warpgate-postgres.example).

## O que é proibido (padrão)

| Proibido | Por quê |
|----------|---------|
| VPN do cliente + SSH/RDP/SQL **direto** no IP do alvo | Sem gravação central, credencial no endpoint, offboarding frágil |
| Guardar senha `root`/SA do cliente no gerenciador pessoal como fluxo diário | Zero target creds |
| Compartilhar uma conta VPN de usuário entre o time | Sem auditoria por pessoa; risco contratual |

## Exceções

Só com **runbook do cliente** marcando `vpn_user_exception` e aprovação.  
Mesmo assim: preferir saltar só para hosts do inventário; MFA na VPN; migrar para connector.

## Checklist rápido por SO (operador)

### Linux
- [ ] `ssh -V` (OpenSSH)
- [ ] Browser
- [ ] DBeaver ou `psql` (se for usar DB)
- [ ] Teste: SSH target lab via Warpgate

### macOS
- [ ] Terminal + OpenSSH (nativo)
- [ ] Browser
- [ ] DBeaver (se DB)
- [ ] Teste: SSH target lab via Warpgate

### Windows
- [ ] OpenSSH Client (Settings → Optional features) ou Windows Terminal
- [ ] Browser (Edge/Chrome)
- [ ] DBeaver (se DB)
- [ ] Teste: mesmo comando `ssh -p 2222 'user:target@wg…'`

## Suporte

Problemas de login Kanidm / roles → plataforma / ArchGuard.  
Target inacessível → conectividade do **site** (connector/VPN), não “falta VPN no seu PC” no modelo padrão.
