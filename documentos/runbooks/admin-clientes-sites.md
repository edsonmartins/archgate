# Admin visual — ArchGate Manager (estilo AWS Console)

> **ADR-009 / ADR-009A** — **ArchGate Manager**: console para configurar a plataforma (não só identidade).  
> Operador abre sessão no **Connect** / UnifiedUI — não aqui.

## Onde

| | |
|--|--|
| URL base | `https://console.archgate.com.br` |
| Produto | **ArchGate Manager** |
| Branding | Sidebar / title: ArchGate Manager |
| Código | `archguard-console` (repo ArchGuard; OIDC client legado `archguard-console`) |
| Persistência sites | SQLite/Postgres (`sites`) — inventário, **sem** senhas de VPN |

### Módulos (navegação)

| Módulo | Rotas | Configura |
|--------|-------|-----------|
| Identidade | `/identities`, `/groups`, `/oauth2`, … | archguard via proxy |
| **Clientes / Sites** | `/sites` | Stack VPN, connector, targets inventário |
| **Gateways** | `/gateways` | Warpgate + Guacamole CRUD |
| **Segredos** | `/secrets` | OpenBao status, engines, leases, unseal |
| **Mentors Axis** | `/integrations/mentors-axis` | Sync proprietários → sites (CP-7) |
| Site → Warpgate | botão **Sincronizar Warpgate** | Materializa targets no bastion |

## Roadmap Manager / control plane (ADR-009)

| Fase | Conteúdo | Status |
|------|----------|--------|
| CP-0 | Sites CRUD + stack | Feito |
| CP-1 | Proxy Warpgate + sync targets | Feito |
| CP-2 | CRUD global targets/roles na UI | Feito (`/gateways` tab Warpgate) |
| CP-3 | Guacamole connections | Feito (`/gateways` tab Guacamole) |
| CP-4 | OpenBao status/leases/unseal | Feito (`/secrets`) |
| CP-5 | Connector checklist/status | Feito (`/sites/$slug` aba Connector) |
| CP-6 | Import/export YAML + audit | Feito (lista Sites: Exportar/Importar; Auditoria) |
| CP-7 | Mentors Axis sync | Feito (`/integrations/mentors-axis`; mock lab) |

## Quem pode usar

| Papel | Permissões |
|-------|------------|
| Super Admin | CRUD completo |
| Tenant Admin | `sites:read` + `sites:update` (escopo tenant) |
| Operador / Viewer | `sites:read` |

## O que configurar na tela

1. **Identidade** — nome, slug, `tenant_*`, ambiente, roles Warpgate  
2. **Conectividade** — tipo ADR-008 + **stack** (`wireguard` / `openvpn` / `openfortivpn` / …), connector id, subnets, host VPN (metadado), MFA  
3. **Targets** — inventário (nome, engine, host, port, roles)  
4. **Estado** — inventariado / connector deployado / smoke OK  

**Não** colocar no formulário: senhas OpenVPN/Forti, chaves WG privadas, tokens SA.

## Fluxo recomendado

```
Admin preenche site no console
  → ops usa stack + connector_id para deploy (deploy/connector/…)
  → targets aplicados no Warpgate (admin gateway / scripts; apply automático = Fase 4)
  → marca checkboxes de estado no console
```

## Seed inicial

Na primeira abertura da lista, se a tabela estiver vazia, o console grava stubs:

- Rio Quality / Grupo Marra **lab**
- Rio Quality / Grupo Marra **produção** (`stack: a_confirmar`)

## Import / export YAML (CP-6)

| Ação | Onde |
|------|------|
| Exportar **todos** | `/sites` → **Exportar YAML** |
| Exportar **um** | Site → botão **YAML** |
| Importar | `/sites` → **Importar YAML** (`.yaml` / multi-doc `---`) |

Formato alinhado a `documentos/runbooks/sites/cliente-site.template.yaml`.  
**Sem segredos** no arquivo. Mutações de site/checklist vão para **Auditoria**.

Store operacional: SQLite do console. Postgres como SoT multi-instância fica com Mentors Axis / CP-7.

## Relação com inventário YAML

| Fonte | Papel |
|-------|--------|
| Console `/sites` | **Admin visual** do dia a dia |
| Export YAML → git | Gitops / backup / review |
| `documentos/runbooks/sites/reais/*.yaml` | Doc de referência (pode importar) |
| `clientes-reais-por-stack.md` | Matriz de revisão |

Manter alinhados ao mudar stack de um cliente real.

## Deploy da feature

```bash
# no runtime, com archguard-src atualizado
bash deploy/archguard/deploy-console.sh
```

Requer rebuild da imagem `archguard-console` com este código.

## Aceite do piloto lab

Critério formal **pass/fail** de “lab finalizado” (não produção / não Fase 4):

- Checklist: [`ACEITE-PILOTO-LAB.md`](./ACEITE-PILOTO-LAB.md)
- Template de evidência: [`sites/smoke-evidence-TEMPLATE.md`](./sites/smoke-evidence-TEMPLATE.md)

