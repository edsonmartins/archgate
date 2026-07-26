# Tasks — add-org-credential-broker

## OCB-0 — Inventário e metadados

- [x] 0.1 Seed inicial P0/P1 (Apple, Play, GCP placeholder, produtos) — owners via `owner_group`  
- [x] 0.2 Schema `org_accounts` (SQLite migrate em `db.ts`)  
- [x] 0.3 API `GET/POST /api/org/v1/accounts` + server fns (sem secret na listagem)  
- [x] 0.4 UI Manager: **Contas da org** + CRUD dialog  
- [x] 0.5 Template YAML exemplo (`documentos/runbooks/org-accounts.inventory.example.yaml`)  
- [x] 0.6 Permissions `org_accounts:read|admin|checkout|approve` + grupos Kanidm  


## OCB-1 — OpenBao + checkout

- [x] 1.1 Paths convencionados `secret/data/org/{cloud,store,product}/*` (policy OpenBao ops)  
- [x] 1.2 Server: `readSecretData` / `writeSecretData` (app token, never browser)  
- [x] 1.3 `checkoutOrgAccountFn` + REST `POST …/accounts/$id/checkout` + table `org_checkouts`  
- [x] 1.4 Reveal one-shot + `recordActivity` (keys only, never values)  
- [x] 1.5 UI checkout modal + copy + check-in; admin “store secret”  
- [x] 1.6 check-in + expireDueCheckouts on read  
- [x] 1.7 Runbook atualizado  
- [x] 1.8 Unit: org-checkouts + org-accounts seed (sqlite)  


## OCB-2 — Dual-control P0

- [x] 2.1 Fluxo `pending` → approve/deny por `org_accounts:approve`  
- [x] 2.2 Bloqueio self-approve  
- [x] 2.3 Notificação opcional `ORG_CHECKOUT_WEBHOOK_URL` (Slack/JSON)  
- [x] 2.4 UI fila “aprovações pendentes”  
- [x] 2.5 Unit tests dual-control + REST approve  


## OCB-3 — Keys e rotação

- [x] 3.1 `auth_kind=api_key` UX dedicada no store secret  
- [x] 3.2 Rotação assistida (`rotate` + `rotated_at`)  
- [x] 3.3 Runbook: preferir API key / SA  


## OCB-4 — Federar produtos

- [x] 4.1 Inventário + matriz no runbook `org-product-oidc-federation.md`  
- [x] 4.2 Plano OIDC Kanidm por produto (client ids + checklist)  
- [x] 4.3 Metadados `federation_status` + `oidc_client_id`; seed `oidc_primary` / break-glass  
- [ ] 4.4 Implementar clients OIDC em cada codebase de produto (fora do console — por squad)

## OCB-5 — Connect (opcional)

- [x] 5.1 Deep link Manager “Contas da org” (`archgate org-accounts` + menu desktop) — role enforced no Manager  
- [x] 5.2 **Não** implementar storage de secret no Connect (só browser → Manager/OpenBao)  

## Aceite transversal

- [x] A1 Offboarding: sessão expirada → 401; revoke fecha org checkouts (`forceCloseCheckoutsForPrincipal`)  
- [x] A2 Nenhuma senha P0 em git/YAML; secret_ref + OpenBao; waiver residual = path vazio até store secret  
- [x] A3 ADR-013 marcado **Aceito**  

