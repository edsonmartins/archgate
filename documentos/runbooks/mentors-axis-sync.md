# Sync Mentors Axis → ArchGate Sites

**Fonte API:** `mentors-axis-server-api`  
Path local: `/Users/edsonmartins/desenvolvimento/mentors-axis-server-api`  
**Console:** https://console.archgate.com.br/integrations/mentors-axis

## Contrato usado (código Axis)

| Item | Valor |
|------|--------|
| Porta default | `9030` (`application.yml`) |
| Login | `POST /api/v1/auth/authenticate` body `{ "email", "password" }` → `access_token` (Archbase) |
| Listar clientes | `GET /api/v1/proprietario/findAll?page=0&size=100` |
| Header multi-tenant | `X-TENANT-IDs: <uuid>` (default app: `a9f814d2-4dae-41f3-851b-8aa3d4706561`) |
| Auth header | `Authorization: Bearer <token>` |
| Whitelist pública | **não** inclui `proprietario/findAll` — precisa JWT |

Campos mapeados de `ProprietarioDto`: `id`, `code`, `descricao`, `cnpj`, `status`, `onPremiseId`, `defaultGroupId`.

## Env no console ArchGate

```bash
# Live
MENTORS_AXIS_URL=http://192.168.1.x:9030   # ou host onde o Axis sobe
MENTORS_AXIS_EMAIL=admin@...
MENTORS_AXIS_PASSWORD=...
# ou token já emitido:
# MENTORS_AXIS_TOKEN=eyJ...

# opcional (default do application.yml Axis)
MENTORS_AXIS_TENANT_ID=a9f814d2-4dae-41f3-851b-8aa3d4706561

# Lab sem serviço HTTP (fixture in-process no console)
MENTORS_AXIS_MOCK=1
```

### Lab com stub HTTP (contrato live — validado 2026-07-11)

Stub Swarm no runtime ArchGate (não é o jar Spring completo; mesmo path de login/list):

```bash
bash deploy/mentors-axis/stub-api/deploy.sh
MENTORS_AXIS_URL=http://archgate-axis_stub:9030 bash deploy/mentors-axis/wire-console-live.sh
```

Credenciais stub: `admin@axis.lab` / `AxisLab2026!` · token `archgate-lab-axis-token`.  
Proprietários seed: `rio_quality`, `grupo_marra`, `acme`.

Evidência lab: health + authenticate + findAll **PASS** na rede `archgate-data`; console em `MENTORS_AXIS_MOCK=0`.

Redeploy console (com envs Axis):

```bash
bash deploy/archguard/deploy-console.sh
```

## O que o sync grava no site ArchGate

| Campo site | Origem Axis |
|------------|-------------|
| `cliente` | `descricao` |
| `slug` | `code` ou slugify(`descricao`) |
| `tenant_group` | `tenant_<slug>` |
| `stack_meta.mentors_axis_id` | `id` |
| `stack` / `tipo` | `a_confirmar` (ops configura VPN no ArchGate) |

**Não** sobrescreve stack/targets já configurados se o site existir (só meta Axis + nome).

## ADR

- `adr/ADR-004-fronteira-archguard-mentors-axis.md`
- `adr/ADR-009-control-plane-admin-console.md` (CP-7)
