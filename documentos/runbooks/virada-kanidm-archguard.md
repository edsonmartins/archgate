# Runbook — virada do IdP: Kanidm → ArchGuard

| Campo | Valor |
|-------|-------|
| Decisão | [ADR-014](../../adr/ADR-014-archguard-substitui-kanidm-como-idp.md) |
| Smoke | `deploy/validation/smoke-archguard-cutover.sh` |
| Reversão | `ARCHGATE_IDP=kanidm` + redeploy |
| Estado | virada não executada |

A troca é seletiva por variável. Com `ARCHGATE_IDP` ausente ou `kanidm`, tudo se
comporta como antes — o código novo não muda o staging até alguém decidir.

---

## 1. Pré-requisitos no ArchGuard

Antes de tocar no ArchGate, o ArchGuard precisa ter:

| Item | Detalhe |
|------|---------|
| Organização | `archgate` |
| Cert | RS256, referenciado por todas as aplicações |
| Aplicações (6) | `archguard-console`, `archgate-connect`, `warpgate`, `guacamole`, `openbao`, `archgate-console-sa` |
| `tokenFormat` | **`JWT-Custom`** com `tokenFields = ["Name","Groups","Email","DisplayName"]` — aplicado por `deploy/archguard/set-token-format.sh` |
| Grupos (8) | `archguard_super_admins`, `archguard_tenant_admins`, `archguard_admins`, `archguard_users`, `archguard_service_desk`, `archguard_viewers`, `tenant_rio_quality`, `tenant_grupo_marra` |
| Usuários | `testadmin`, `testuser` (suíte E2E) + personas UAT |
| Redirects | Connect `http://127.0.0.1:8765/callback` · OpenBao `http://127.0.0.1:8250/oidc/callback` |

Os grupos ficam com **nome plano**. O Casdoor compõe `<org>/<nome>` sozinho ao
gravar a associação; nomear o grupo já com o prefixo produziria
`archgate/archgate/...`.

### Por que `JWT-Custom` não é opcional

No formato `JWT`, o token carrega o objeto `User` inteiro e o saneamento do
Casdoor limpa apenas a senha — `totpSecret`, `recoveryCodes`, `passwordSalt` e
`passwordType` sobrevivem. Esse token vai para o Warpgate, para o oauth2-proxy
do Guacamole e para o OpenBao. Quem lê o token clona o segundo fator.

O smoke falha explicitamente nesse caso. **Não vire com o formato `JWT`.**

---

## 2. Variáveis (bootstrap.env)

```bash
ARCHGATE_IDP=archguard
ARCHGATE_IDP_URL=https://app.archguard.com.br
ARCHGATE_IDP_ORG=archgate

# Console: substituem o ARCHGUARD_SA_TOKEN opaco
ARCHGUARD_ID_URL=https://app.archguard.com.br
ARCHGUARD_SA_CLIENT_ID=<clientId da app archgate-console-sa>
ARCHGUARD_SA_CLIENT_SECRET=<secret>

# OpenBao: no Casdoor o aud é o clientId, não o nome da aplicação
OPENBAO_OIDC_AUDIENCE=<clientId da app openbao>
```

`ARCHGUARD_SA_TOKEN` deixa de ser usado. O console agora obtém um bearer curto
por `client_credentials` e renova no 401.

---

## 3. Ordem de execução

### Passo 0 — formato do token (bloqueador)

```bash
export ARCHGATE_IDP_URL=https://app.archguard.com.br
export ARCHGUARD_SA_CLIENT_ID=... ARCHGUARD_SA_CLIENT_SECRET=...

bash deploy/archguard/set-token-format.sh           # dry-run: mostra o que mudaria
APPLY=1 bash deploy/archguard/set-token-format.sh   # escreve
```

Idempotente e de escrita estreita: só as colunas `token_format` e `token_fields`
das 6 aplicações. Reexecutar é seguro. Confirma relendo cada aplicação — o
Casdoor responde 200 com `status: error` em alguns casos.

### Passo 1 — smoke camada A (não invasivo)

```bash
ARCHGATE_IDP_URL=https://app.archguard.com.br \
ARCHGUARD_SA_CLIENT_ID=... ARCHGUARD_SA_CLIENT_SECRET=... \
  bash deploy/validation/smoke-archguard-cutover.sh
```

Valida discovery, JWKS com `kid`, `client_credentials` e escrita pela SA. Cria o
grupo `archgate-smoke-tmp` — remova depois.

### Passo 2 — smoke camada B (a que importa)

```bash
ARCHGATE_IDP=archguard ARCHGATE_IDP_URL=https://app.archguard.com.br archgate login
export ARCHGATE_SMOKE_TOKEN="$(archgate auth-header | sed 's/^Bearer //')"

ARCHGATE_IDP_URL=https://app.archguard.com.br \
EXPECT_AUD=<clientId da app openbao> \
OPENBAO_ADDR=http://127.0.0.1:8200 \
  bash deploy/validation/smoke-archguard-cutover.sh
```

Aqui a premissa central se confirma ou cai: **o claim `groups` sai qualificado
como `archgate/<nome>`?** Três configurações dependem disso.

Se sair sem prefixo, o smoke diz REFUTADA e nomeia os arquivos a editar:
`deploy/warpgate/deploy.sh` e `deploy/openbao/bootstrap-kanidm-auth.sh`.

### Passo 3 — bloqueador

Se o smoke acusar `TOKEN VAZA`, pare. Troque as 6 aplicações para `JWT-Custom` e
volte ao passo 2. Não siga com segredo de MFA circulando.

### Passo 4 — virar

```bash
# no host de runtime
./scripts/62-wire-console-integrations.sh     # console
bash deploy/openbao/bootstrap-kanidm-auth.sh  # roles do cofre (agora IdP-aware)
bash deploy/warpgate/deploy.sh                # SSO + role_mappings
bash deploy/guacamole/oauth2-proxy-deploy.sh  # portão do Guacamole
```

### Passo 5 — verificar

| Cenário | Comando |
|---|---|
| Login no Manager | browser em `console.archgate.com.br`, conferir grupos na sessão |
| Catálogo por tenant | `uat-op-a` vê alvos Rio, não vê Marra |
| Cofre | `bao write auth/jwt/login role=archgate-operator jwt=$TOKEN` |
| Bastion | `ssh -p 2222 'uat-op-a:rio-lab-ssh@wg.archgate.com.br'` |
| Offboarding | desabilitar no ArchGuard → próximo login negado |

---

## 4. Reversão

```bash
ARCHGATE_IDP=kanidm   # ou remover a variável
```

E reexecutar os quatro scripts do passo 4. Nenhum dado do Kanidm é destruído
pela virada — os dois IdPs coexistem até você desligar o Kanidm por decisão
separada.

Durante a convivência, uma sessão pode carregar grupos de qualquer um dos dois
formatos; a normalização do console trata ambos.

---

## 5. Residual conhecido

**A revogação não propaga para tokens já emitidos.** Os endpoints OIDC v1 do
ArchGuard (rotação de refresh, back-channel logout, `pcid`) existem no domínio
mas não estão montados nas rotas — quem serve OAuth é o Casdoor legado.

Desabilitar a pessoa bloqueia o **próximo** login; um access token vivo vale até
expirar. **Com access de 1h, a janela é ≤ 1h.**

Isso precisa constar como ressalva no gate de homologação, porque a promessa do
produto é "revogar identidade = revogar acesso" (CONSTITUTION §2.4). O
offboarding do Manager compensa parcialmente: também revoga no Warpgate, na
orquestração e nos leases do OpenBao.

Ver ADR-014, §Consequências.
