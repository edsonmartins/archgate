# Org Credential Broker — runbook (esboço)

| Campo | Valor |
|-------|--------|
| Status | OCB-0 live (metadados); checkout OCB-1 pendente |
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

## Operação (quando OCB-1+ estiver live)

1. Login Manager (SSO Kanidm)  
2. **Contas da org** → selecionar conta  
3. **Checkout** → motivo + TTL  
4. P0: aguardar aprovação de segundo admin  
5. Copiar secret; usar no portal; **não** colar no Slack  
6. Check-in ou esperar expirar  

## Offboarding

Desabilitar pessoa no Kanidm → perde Manager e checkout.  
Rotacionar secrets P0 se a pessoa tinha acesso ativo recente (runbook de incidente).

## Break-glass

Conta owner Apple/GCP: dual-control + recovery codes em path separado com `requires_dual_control=true`.

## Relação com Connect

Connect **não** armazena essas senhas. Acesso a infra de cliente continua bastion-first (sites/targets).
