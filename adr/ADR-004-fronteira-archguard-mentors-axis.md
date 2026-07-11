# ADR-004 — Fronteira ArchGuard × Mentors Axis

- **Status:** Aceito (implementação lab parcial)
- **Data:** 2026-07-11 (atualizado)
- **Relacionado:** ADR-009 (control plane), Fase 4 UnifiedUI/orquestração

## Contexto

Mentors Axis já é multi-tenant e registra **clientes (Proprietário)**. ArchGate precisa de tenants de acesso (`tenant_*` no Kanidm), sites/conectividade e gateways. Sem fronteira clara, há risco de duplicar cadastro de cliente e de misturar orquestração comercial com bastion.

## Decisão

| Responsabilidade | Dono |
|------------------|------|
| Cadastro comercial do cliente (nome, CNPJ, status, contratos) | **Mentors Axis** (`/api/v1/proprietario`) |
| Identidade técnica (pessoas, grupos, OAuth2, SSO) | **ArchGuard / Kanidm** (console) |
| Acesso privilegiado (sites, stack VPN, targets, connectors, OpenBao) | **ArchGate Control Plane** (console) |
| Orquestração multi-sistema **full** (pessoas, grant/revoke, offboarding) | **Fase 4+** (HITL / API) |
| Sync **leitura** Axis → fichas de site + bootstrap tenant/role | **Control plane** (CP-7, lab) |

### Fluxo CP-7 (implementado no lab)

```
Mentors Axis GET /api/v1/proprietario/findAll
        ↓ (server-side JWT ou token; nunca no browser)
ArchGate sites (PostgreSQL SoT, fallback SQLite)
  slug ← code | slugify(descricao)
  tenant_group ← tenant_<slug>
  stack_meta.mentors_axis_id / code / status / admin_email
  stack permanece a_confirmar até ops configurar VPN
        ↓
Kanidm: ensure grupo tenant_<slug> (idempotente)
Warpgate: ensure role tenant-<slug> (idempotente)
```

- **Não** apaga sites locais não presentes no Axis (só upsert).  
- **Não** grava segredos Axis no browser.  
- **Não** cria pessoas/operadores automaticamente (Fase 4 / HITL).  
- **Sim** cria/garante grupo Kanidm `tenant_*` e role Warpgate no sync.

### Lab (staging IntegrAllTech)

| Peça | Estado |
|------|--------|
| Spring Axis | Serviço `archgate-axis-spring` (host **:9031**, Swarm DNS `:9030`) |
| MySQL Axis | `192.168.1.110:3308/axis` |
| Stub Python | `archgate-axis_stub` **0/0** (fallback; redeploy via `stub-api/deploy.sh`) |
| Console | `MENTORS_AXIS_URL` + email/password (JWT); `MOCK=0` |
| Script deploy Spring | `deploy/mentors-axis/deploy-spring-lab.sh` |
| Script wire console | `deploy/mentors-axis/wire-console-live.sh` |
| Script sync CLI (ops) | `deploy/mentors-axis/sync-tenants-cli.sh` |

## Consequências

**+** Um cadastro comercial (Axis) alimenta inventário de acesso (ArchGate).  
**+** Ops configura VPN/targets só no control plane.  
**+** Bootstrap de isolamento tenant (Kanidm + Warpgate role) no sync.  
**−** Auth/mTLS console↔Axis a endurecer em produção (hoje env/JWT lab).  
**−** Offboarding full e provision de pessoas = Fase 4.
