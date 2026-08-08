# Org Credential Broker — runbook operacional

| Campo | Valor |
|-------|--------|
| Status | OCB-0…**OCB-5** + **Manager-only ops** (settings/health/ensure write) |
| ADR | [ADR-013](../../adr/ADR-013-org-credential-broker.md) · [ADR-009](../../adr/ADR-009-control-plane-admin-console.md) (console estilo AWS) |
| OpenSpec | `openspec/changes/add-org-credential-broker/` |
| Superfície | **Só ArchGate Manager** — sem UI archguard/OpenBao no dia a dia |

## Princípio (AWS Console)

Toda operação do broker é feita em **`https://console.archgate.com.br` → Contas da org**.

| Você faz no Manager | Backend invisível |
|--------------------|-------------------|
| Inventário, checkout, dual-control | — |
| Gravar / rotacionar secret | Secrets store (OpenBao via BFF) |
| Pessoas / grupos / OAuth2 clients | IdP (archguard via BFF) |
| Config webhook + TTL | SQLite settings do console |
| Status do broker (health) | Probe canário no backend |

**Não** abra UI do OpenBao nem do archguard para o fluxo normal.  
Se o status do broker estiver degradado, isso é **bootstrap de plataforma** (admin de plataforma / deploy) — não o runbook do operador.

## Objetivo

Centralizar **contas da IntegrAllTech** (não targets de cliente): inventário, secret no backend, checkout com TTL, dual-control P0, audit e offboarding.

## Fluxo diário (admin / aprovador)

### 1. Status

1. Login Manager (SSO)  
2. **Acesso → Contas da org**  
3. Card **Status do broker**  
   - **Operacional** + **Secrets OK** → pode gravar e fazer checkout  
   - **Degradado** → contate admin de plataforma (não use outra ferramenta “no meio tempo”)

### 2. Inventário

1. Seed automático no primeiro acesso com permissão  
2. **Nova conta** / editar metadados (categoria, P0/P1, federação, client OIDC)  
3. `secret_ref` é opcional — **Gravar secret** cria o path padrão  
4. Template YAML (sem senhas): `org-accounts.inventory.example.yaml`

### 3. Gravar / rotacionar secret

1. Ícone cadeado na linha  
2. Password ou API key  
3. Opcional: marcar rotação (`rotated_at`)  
4. Path padrão se vazio: `secret/data/org/{category}/{slug}`  
5. Erros vêm em linguagem do console (sem “abra o OpenBao”)

### 4. Checkout

1. **Checkout** → motivo (≥3) + TTL (limites vêm das **Configurações do broker**)  
2. P0 / dual-control → fica **pending** até outro admin aprovar  
3. Reveal one-shot; **Check-in** ao terminar  
4. Auditoria no menu **Auditoria**

### 5. Dual-control P0

1. Fila **Aprovações pendentes**  
2. Outro principal com `org_accounts:approve`  
3. Self-approve proibido  
4. Webhook opcional: **Configurações do broker** → URL HTTPS (Slack ou genérica)

### 6. Configurações do broker (Manager-only)

Botão **Configurações do broker**:

| Campo | Efeito |
|-------|--------|
| Webhook HTTPS | Notifica dual-control pending |
| TTL padrão / máximo | Limites do checkout |

Prioridade webhook: **setting do Manager** → fallback env de bootstrap (`ORG_CHECKOUT_WEBHOOK_URL`) só se setting vazio.

### 7. Federação / SSO produto

- Metadados `federation_status` + `oidc_client_id` no inventário  
- Registrar client em **OAuth2 / SSO** neste mesmo Manager  
- Implementação do IdP adapter **no produto** = residual 4.4 (squad)  
- Detalhe: [org-product-oidc-federation.md](./org-product-oidc-federation.md)

### 8. Offboarding

1. Manager → **Identidades** → Revogar acesso  
2. Login bloqueado + checkouts org do principal fechados  
3. Rotacionar secrets P0 se houve reveal recente (incidente)

## API (mesmo contrato do UI)

```http
GET  /api/org/v1/accounts
POST /api/org/v1/accounts
POST /api/org/v1/accounts/:id/checkout
POST /api/org/v1/checkouts/:id/approve
```

Server fns (Manager): `getOrgBrokerHealthFn`, `getOrgBrokerSettingsFn`, `saveOrgBrokerSettingsFn`, `storeOrgAccountSecretFn`.

## Connect (OCB-5)

```bash
archgate org-accounts   # browser → /org-accounts
```

Sem vault local no Connect.

## Bootstrap de plataforma (fora do dia a dia)

Só na **instalação / incidente de plataforma** (scripts devops), não no runbook do admin de contas:

- Credencial de app do backend de secrets no serviço console  
- Unseal se o backend estiver selado  
- Mount/policy `secret/data/org/*` no app token  

O admin de contas **só** usa o card de status e contata plataforma se falhar.

## Aceite A2 — sem senha P0 em chat/planilha

| Controle | Estado |
|----------|--------|
| Inventário no Manager | SoT metadados |
| Git/YAML | sem password values |
| Secret | só via **Gravar secret** no Manager |
| Connect | sem vault local |
| Dual-control P0 | obrigatório |

**Waiver residual:** conta pode ter path antes do material — checkout pede “Gravar secret”.

## Break-glass

Owner Apple/GCP: dual-control + recovery codes em conta separada com `requires_dual_control=true`.
