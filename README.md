# ArchGate

Plataforma de **acesso privilegiado** (bastion/gateway) da IntegrAllTech.

Operadores e agentes acessam máquinas, bancos, Kubernetes e painéis de clientes **sem receber a credencial do alvo**. Identidade é central (offboarding em um ponto); sessões são auditáveis; a stack roda **self-hosted** (LGPD / soberania de dados).

**ArchGuard** é o módulo de identidade dentro do ArchGate — *“o Guard controla quem passa pelo Gate”* (ver [ADR-005](adr/ADR-005-nome-do-produto-archgate.md)).

> Repositório privado · monorepo de produto, governança OpenSpec, ADRs e deploy Docker Swarm.

---

## Por quê

| Problema atual | Com ArchGate |
|----------------|--------------|
| Credenciais de cliente nas máquinas dos devs | Gateway injeta o segredo; o dev não vê |
| Offboarding = rotacionar dezenas de senhas | Revoga identidade no Kanidm → acesso cai |
| Auditoria fraca / espalhada | Sessões gravadas no bastion (WG / Guac) |
| Escala multi-cliente manual | Tenants + inventário de sites + control plane |

Princípios: **zero-credencial-no-dev**, política no gateway, identidade como alicerce, efemeridade por padrão, API-first.

Documento de arquitetura: [`PLATAFORMA_ACESSO_PRIVILEGIADO.md`](./PLATAFORMA_ACESSO_PRIVILEGIADO.md).  
Invariantes: [`CONSTITUTION.md`](./CONSTITUTION.md).  
Plano 100%: [`documentos/PLAN-PRODUTO-100.md`](./documentos/PLAN-PRODUTO-100.md).

| Serviço (scaffold) | Path | Porta dev |
|--------------------|------|-----------|
| UnifiedUI | `frontend/unified-ui` | 5174 |
| Orchestration (Axis) | `services/orchestration` | 8090 |
| Agent control (OpenSRE) | `services/agent-control` | 8091 |
| Oracle proxy | `services/oracle-proxy` | (Spring) |

---

## Arquitetura (visão)

```
Operador / agente
       │
       ▼
┌──────────────────┐     ┌─────────────────┐
│ ArchGuard Console│────▶│ Kanidm (OIDC)   │  identidade
└────────┬─────────┘     └────────┬────────┘
         │                        │ JWT / SSO
         ▼                        ▼
┌──────────────────┐     ┌─────────────────┐
│ Control plane    │     │ OpenBao         │  segredos efêmeros
│ (sites, apply,   │     │ (SSH CA, DB dyn)│
│  Axis sync)      │     └────────┬────────┘
└────────┬─────────┘              │
         │                        │
         ▼                        ▼
┌──────────────────────────────────────────┐
│ Gateways: Warpgate (SSH/PG/…) + Guacamole│
│           (browser RDP/VNC/SSH)          │
└────────────────────┬─────────────────────┘
                     │ connector / VPN site
                     ▼
              Redes dos clientes
```

| Camada | Papel | Componente |
|--------|-------|------------|
| Controle | Tenants, sites, orquestração | Mentors Axis + console ArchGuard |
| Identidade | SSO, RBAC, service accounts | **Kanidm** (via ArchGuard) |
| Gateway | Proxy + gravação | **Warpgate** + **Apache Guacamole** |
| Segredos | Credenciais de curta duração | **OpenBao** |
| Rede | Alcance aos sites | Connector site (WG/OpenVPN/…) · NetBird (fase futura) |
| Borda | TLS / roteamento | **Traefik** + Cloudflare Tunnel |

Console de identidade e UI admin vivem no repositório irmão **`archguard`** (`archguard-console`); este monorepo concentra **produto ArchGate**, deploy, specs e runbooks.

---

## Estado do lab (piloto)

Ambiente de staging: host runtime Swarm `edson-ai` · domínio `*.archgate.com.br`.

| Pacote OpenSpec | Status |
|-----------------|--------|
| `add-identity-axis` | Lab complete (Kanidm, WG, Guac portão, console, multi-tenant) |
| `add-operator-client-access-standard` | Lab-ready (ADR-008, smoke operador, bastion-first) |
| `add-ephemeral-credentials` | MVP lab (OpenBao, JWT←Kanidm, broker DB) |
| Control plane admin (ADR-009) | Lab: sites SoT, apply gateways, Axis sync, `/platform` |
| Aceite piloto | **PASS com waiver** — ver runbooks |

Matriz viva: [`documentos/MATRIZ_FUNCIONALIDADES.md`](./documentos/MATRIZ_FUNCIONALIDADES.md)  
Checklist de aceite: [`documentos/runbooks/ACEITE-PILOTO-LAB.md`](./documentos/runbooks/ACEITE-PILOTO-LAB.md)

### Hostnames públicos (lab)

| Host | Serviço |
|------|---------|
| `id.archgate.com.br` | Kanidm |
| `console.archgate.com.br` | ArchGuard Console |
| `wg.archgate.com.br` | Warpgate (UI + SSH `:2222` + PG `:55432`) |
| `guac.archgate.com.br` | Guacamole (portão oauth2-proxy) |

---

## Estrutura do repositório

```
adr/                 Decisões de arquitetura (ADR-00x)
openspec/            Changes, designs, specs e tasks (governança)
deploy/              Docker Swarm stacks, Traefik, connectors, validação
documentos/          Runbooks, inventário de sites, matriz, evidências
services/            Serviços próprios (Oracle proxy, orquestração — fases futuras)
frontend/            UnifiedUI (Fase 4)
CONSTITUTION.md      Invariantes do produto
PLATAFORMA_ACESSO_PRIVILEGIADO.md
```

### Deploy (resumo)

```bash
# No host runtime (Swarm), com bootstrap.env fora do git (mode 600):
# ver deploy/README.md e deploy/env.example/bootstrap.env

./deploy/bootstrap-networks.sh
# stacks: traefik → postgres (externo) → archguard/kanidm → warpgate → guacamole → openbao → console
```

Versões **pinadas** em [`deploy/versions.env`](./deploy/versions.env) — nunca `latest` em staging/prod.

Segredos: `bootstrap.env` e chaves age **fora do git** (ver [`.gitignore`](./.gitignore)).

---

## Documentação — mapa de leitura

| Ordem | Documento | Conteúdo |
|------:|-----------|----------|
| 1 | [`CONSTITUTION.md`](./CONSTITUTION.md) | Invariantes (precede tudo) |
| 2 | [`INICIAR_ARCHGATE.md`](./INICIAR_ARCHGATE.md) | Como começar a trabalhar no repo |
| 3 | [`PLATAFORMA_ACESSO_PRIVILEGIADO.md`](./PLATAFORMA_ACESSO_PRIVILEGIADO.md) | Arquitetura completa |
| 4 | [`openspec/project.md`](./openspec/project.md) | Stack, topologia, convenções |
| 5 | [`openspec/changes/README.md`](./openspec/changes/README.md) | Fases e pacotes |
| 6 | [`deploy/README.md`](./deploy/README.md) | Swarm, redes, stacks |
| 7 | [`documentos/runbooks/`](./documentos/runbooks/) | Operação, operador multi-OS, aceite |
| 8 | [`documentos/PLAN-HOMOLOGACAO-MVP.md`](./documentos/PLAN-HOMOLOGACAO-MVP.md) | **Plano de tarefas** até homologação MVP |
| 9 | [`documentos/PLAN-PRODUTO-100.md`](./documentos/PLAN-PRODUTO-100.md) | **Plano até 100% do produto** (W0–W5) |
| 9b | [`documentos/runbooks/W0-EXECUCAO.md`](./documentos/runbooks/W0-EXECUCAO.md) | Execução onda W0 (auto + browser + peer) |
| 10 | [`documentos/runbooks/HOMOLOGACAO-UAT.md`](./documentos/runbooks/HOMOLOGACAO-UAT.md) | Roteiro UAT (revisor, ≤30 min) |

### ADRs relevantes

- [ADR-003](adr/ADR-003-persistencia-externa-postgresql.md) — PostgreSQL externo (sem SQLite em prod)
- [ADR-004](adr/ADR-004-fronteira-archguard-mentors-axis.md) — Fronteira ArchGuard × Mentors Axis
- [ADR-005](adr/ADR-005-nome-do-produto-archgate.md) — Nome do produto
- [ADR-007A](adr/ADR-007A-oauth2-proxy-guacamole-sso.md) — SSO Guacamole via oauth2-proxy
- [ADR-008](adr/ADR-008-cliente-operador-hibrido-multi-os.md) — Cliente operador híbrido (browser + desktop)
- [ADR-009](adr/ADR-009-control-plane-admin-console.md) — Control plane no console

---

## Acesso do operador (padrão)

**Bastion-first** (ADR-008): o notebook **não** liga VPN de cliente + SSH direto no IP do alvo.

```bash
# SSH via Warpgate (exemplo lab)
ssh -p 2222 'usuario:rio-lab-ssh@wg.archgate.com.br'

# Postgres via Warpgate
# host=wg… port=55432 user=usuario:rio-lab-postgres sslmode=require
```

Snippets: [`documentos/runbooks/snippets/`](./documentos/runbooks/snippets/)  
Runbook multi-OS: [`documentos/runbooks/cliente-operador-multi-os.md`](./documentos/runbooks/cliente-operador-multi-os.md)

Smoke:

```bash
WG_HOST=192.168.1.180 bash deploy/validation/smoke-operator-access.sh
```

---

## Validação e aceite

| Script / doc | Uso |
|--------------|-----|
| `deploy/validation/smoke-operator-access.sh` | SSH + PG via bastion |
| `deploy/validation/tenant-isolation-e2e.sh` | Isolamento tenant |
| `deploy/openbao/smoke-kanidm-jwt.sh` | JWT Kanidm → OpenBao |
| `documentos/runbooks/ACEITE-PILOTO-LAB.md` | Checklist pass/fail lab |
| `documentos/runbooks/sites/smoke-evidence-*.md` | Evidências datadas |

---

## Stack e versões (lab)

| Componente | Versão pinada (referência) |
|------------|----------------------------|
| Traefik | v3.4.x |
| Kanidm | 1.10.x |
| Warpgate | 0.26.x |
| Guacamole / guacd | 1.6.x |
| OpenBao | 2.x |
| PostgreSQL (externo) | 16.x |
| Console | Node / TanStack Start (repo `archguard`) |
| Axis (lab) | Spring Boot :9031 |

Detalhes e pins: [`deploy/versions.env`](./deploy/versions.env) · [`openspec/project.md`](./openspec/project.md).

---

## Roadmap (alto nível)

| Fase | Foco |
|------|------|
| **1** | Identidade + gateways + console + padrão operador — **lab** |
| **2** | Credenciais efêmeras (OpenBao) — **MVP lab** |
| **3** | Malha / connectors site; Oracle proxy (3a) |
| **4** | UnifiedUI + orquestração completa Axis |
| **5** | HA, acesso agêntico, OpenSRE adjacente |

Itens **fora** do aceite lab: peer VPN de cliente real em produção, UnifiedUI, HA OpenBao, SIEM, NetBird full.

---

## Contribuição interna

1. Ler `CONSTITUTION.md` e o change OpenSpec da fase.
2. Implementar **uma** tarefa de `tasks.md` por vez; marcar `[x]` só após validar o cenário.
3. Commits: referenciar change e tarefa quando aplicável (`add-identity-axis #2.5`).
4. Documentação e specs em **pt-BR**; código/identificadores em **inglês**.
5. Nunca commitar `bootstrap.env`, tokens ou gravações de sessão.

Relacionados:

- `../archguard` — console + integração Kanidm
- Mentors Axis — plano de controle de tenants (API Spring no lab)

---

## Licença

Código e documentação proprietários da **IntegrAllTech**. Engines de terceiros mantêm suas licenças (Kanidm/OpenBao MPL-2.0, Guacamole Apache-2.0, Warpgate open-source, etc.).
