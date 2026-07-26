# Org Credential Broker — runbook (esboço)

| Campo | Valor |
|-------|--------|
| Status | OCB-0 + OCB-1 + **OCB-2 dual-control** live |
| ADR | [ADR-013](../../adr/ADR-013-org-credential-broker.md) |
| OpenSpec | `openspec/changes/add-org-credential-broker/` |
| Superfície | ArchGate Manager (`console.archgate.com.br`) |

## Objetivo

Centralizar **contas da IntegrAllTech** (não targets de cliente): inventário, OpenBao, checkout com TTL, dual-control P0, audit e offboarding via Kanidm.

## Inventário inicial sugerido (OCB-0)

Preencher e importar (YAML/CSV) — **sem colar senhas no git**.

| slug | category | criticality | owner_group | url |
|------|----------|-------------|-------------|-----|
| apple-appstore-integrall | store | P0 | archguard_super_admins | https://appstoreconnect.apple.com |
| google-play-integrall | store | P0 | archguard_super_admins | https://play.google.com/console |
| gcp-… | cloud | P0/P1 | … | https://console.cloud.google.com |
| vendax-admin-… | product_admin | P1 | … | … |
| archflow-admin-… | product_admin | P1 | … | … |
| brainsentry-admin-… | product_admin | P1 | … | … |
| gestor-admin-… | product_admin | P1 | … | … |
| alcada-admin-… | product_admin | P1 | … | … |

Segredos só no OpenBao após OCB-1:

```text
secret/data/org/store/apple-appstore
secret/data/org/store/google-play
secret/data/org/cloud/gcp-…
secret/data/org/product/vendax-…
```

## OCB-0 — Manager

1. Login `https://console.archgate.com.br`  
2. Menu **Acesso → Contas da org**  
3. Seed automático na primeira listagem (admin/read)  
4. CRUD metadados; campo `secret_ref` = path OpenBao (valor do secret **não** aparece)  
5. Template inventário: `documentos/runbooks/org-accounts.inventory.example.yaml`  

API:

```http
GET  /api/org/v1/accounts
POST /api/org/v1/accounts
```

## OCB-1 — Checkout

1. Login Manager (SSO Kanidm)  
2. **Contas da org**  
3. Admin (cadeado): **gravar secret** no OpenBao (password/api_key) se ainda vazio  
4. **Checkout** → motivo (≥3 chars) + TTL (5 min–8 h)  
5. Copiar secret; usar no portal; **não** colar no Slack  
6. **Check-in** ou esperar `expires_at`  
7. Auditoria: menu **Auditoria** (action “Checkout conta org”)  

```http
POST /api/org/v1/accounts/:id/checkout
{ "reason": "release iOS", "ttl_seconds": 3600 }
```

Requisitos: `OPENBAO_APP_TOKEN` no console com read/write em `secret/data/org/*`.

### Dual-control P0 (OCB-2)

1. Conta com `requires_dual_control` (default P0) → checkout fica **pending** (sem secret)  
2. Outro admin com `org_accounts:approve` vê a fila **Aprovações pendentes**  
3. **Aprovar** → secret revelado ao aprovador (one-shot); **Negar** encerra  
4. **Self-approve proibido** (mesmo principal)  
5. Solicitante pode **Cancelar meu pedido** (check-in)

```http
POST /api/org/v1/checkouts/:id/approve
```

## Offboarding

Desabilitar pessoa no Kanidm → perde Manager e checkout.  
Rotacionar secrets P0 se a pessoa tinha acesso ativo recente (runbook de incidente).

## Break-glass

Conta owner Apple/GCP: dual-control + recovery codes em path separado com `requires_dual_control=true`.

## Relação com Connect

Connect **não** armazena essas senhas. Acesso a infra de cliente continua bastion-first (sites/targets).
