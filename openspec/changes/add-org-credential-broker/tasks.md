# Tasks — add-org-credential-broker

## OCB-0 — Inventário e metadados

- [x] 0.1 Seed inicial P0/P1 (Apple, Play, GCP placeholder, produtos) — owners via `owner_group`  
- [x] 0.2 Schema `org_accounts` (SQLite migrate em `db.ts`)  
- [x] 0.3 API `GET/POST /api/org/v1/accounts` + server fns (sem secret na listagem)  
- [x] 0.4 UI Manager: **Contas da org** + CRUD dialog  
- [x] 0.5 Template YAML exemplo (`documentos/runbooks/org-accounts.inventory.example.yaml`)  
- [x] 0.6 Permissions `org_accounts:read|admin|checkout|approve` + grupos Kanidm  


## OCB-1 — OpenBao + checkout

- [ ] 1.1 Paths e policies OpenBao `secret/data/org/{cloud,store,product}/*`  
- [ ] 1.2 Server proxy: read/write KV com app token (nunca no browser)  
- [ ] 1.3 `POST …/checkout` com reason + TTL + `OrgCheckout`  
- [ ] 1.4 Reveal one-shot + audit activity_log  
- [ ] 1.5 UI: botão checkout, modal motivo/TTL, exibir secret com copy + auto-hide  
- [ ] 1.6 `POST …/checkin` + job/TTL expire status  
- [ ] 1.7 Runbook `documentos/runbooks/org-credential-broker.md`  
- [ ] 1.8 Testes unit/integration (RBAC, sem secret em list, audit)  

## OCB-2 — Dual-control P0

- [ ] 2.1 Fluxo `pending` → approve/deny por `org_accounts:approve`  
- [ ] 2.2 Bloqueio self-approve  
- [ ] 2.3 Notificação (e-mail/Slack webhook opcional)  
- [ ] 2.4 UI fila “aprovações pendentes”  
- [ ] 2.5 Evidence smoke dual-control  

## OCB-3 — Keys e rotação

- [ ] 3.1 `auth_kind=api_key` UX dedicada  
- [ ] 3.2 Rotação assistida (write novo secret + marca `rotated_at`)  
- [ ] 3.3 Preferir service account / API key nos runbooks GCP/Play/Apple  

## OCB-4 — Federar produtos

- [ ] 4.1 Inventário de produtos com senha admin ainda necessária  
- [ ] 4.2 Plano OIDC Kanidm por produto (Vendax, Gestor, …)  
- [ ] 4.3 Marcar contas `auth_kind=oidc` e arquivar password break-glass  

## OCB-5 — Connect (opcional)

- [ ] 5.1 Deep link Manager “Contas da org” se role permitir  
- [ ] 5.2 **Não** implementar storage de secret no Connect  

## Aceite transversal

- [ ] A1 Offboarding: user disabled → 401/403 no módulo  
- [ ] A2 Nenhuma senha P0 só em chat/planilha (waiver se residual)  
- [ ] A3 ADR-013 marcado Aceito após review  
