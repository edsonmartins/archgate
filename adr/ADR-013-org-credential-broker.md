# ADR-013 — Org Credential Broker (contas da IntegrAllTech)

- **Status:** Aceito
- **Data:** 2026-07-26
- **Implementação:** OCB-0…OCB-5 no Manager + Connect deep-link; residual 4.4 = OIDC por produto (squads)
- **Relacionado:** [CONSTITUTION](../CONSTITUTION.md) §2 · [ADR-009](./ADR-009-control-plane-admin-console.md) Manager · [ADR-009A](./ADR-009A-archgate-manager-produto.md) · OpenBao (CP-4) · [ADR-008A](./ADR-008A-archgate-connect-cliente-operador.md) Connect (fora do happy path)
- **OpenSpec:** `openspec/changes/add-org-credential-broker/`
- **Runbook:** [org-credential-broker.md](../documentos/runbooks/org-credential-broker.md)

## Contexto

Além do acesso privilegiado a **infra de clientes** (sites, Warpgate, Guacamole), a IntegrAllTech opera com um segundo problema de credenciais:

| Domínio | Exemplos |
|---------|----------|
| Nuvem / lojas | Google Cloud, Google Play Console, Apple App Store Connect |
| Produtos da casa | ArchFlow, ArchGuard, Vendax, Gestor RQ, BrainSentry, Alçada, … |
| Fornecedores / admin | portais com login/senha, API keys, recovery codes |

Hoje isso está **espalhado** (senhas diferentes, URLs, “pergunta pro Fulano”, cofres pessoais). Não há inventário único, offboarding fraco, sem audit de *quem viu o que*, e misturar isso com targets de cliente no Connect seria errado.

O OpenBao e o Manager já existem para **segredos de plataforma**; falta um **módulo de produto** com política PAM (checkout, TTL, dual-control), sem virar password manager genérico.

## Decisão

### 0. Console único (ADR-009 — metáfora AWS Console)

O **ArchGate Manager** é o **único console operacional**, no mesmo espírito da **AWS Console**:

| AWS | ArchGate |
|-----|----------|
| Console (UI + API) | **ArchGate Manager** (`console.archgate.com.br` + `/api/…`) |
| IAM | Módulo identidade (Kanidm **atrás** do BFF) |
| Secrets Manager / Parameter Store | OpenBao **atrás** do BFF |
| CLI (opcional) | Connect / `archgate` — **sem** vault local de org |

**Regra:** o admin/operador **não** precisa de UI/CLI do Kanidm, OpenBao, Warpgate stock, etc. no fluxo normal.  
Esses componentes são **backends** (como serviços AWS por trás do Console). UIs stock = “advanced / break-glass de plataforma”, não o happy path ([ADR-009](./ADR-009-control-plane-admin-console.md)).

Bootstrap de instalação (deploy scripts, tokens de serviço) é **ops de plataforma 1×**, análogo a provisionar a conta AWS — não o dia a dia.

### 1. Novo módulo no **ArchGate Manager**: Org Accounts / Credential Broker

| Superfície | Papel |
|------------|--------|
| **ArchGate Manager** | **Única** UI/API: catálogo, checkout, aprovação, store/rotate secret, audit |
| **OpenBao** | Backend de material secreto (`secret/data/org/…`) — **sem** uso diário da UI OpenBao |
| **Kanidm** | Backend de identidade/RBAC/OIDC clients — **via** Identidades / Grupos / OAuth2 no Manager |
| **ArchGate Connect** | **Não** é o vault; deep-link `archgate org-accounts` → Manager (sem storage local) |

### 2. Separar bolsos de segredo

| Path (conceito) | Conteúdo |
|-----------------|----------|
| `secret/data/org/cloud/*` | GCP, etc. |
| `secret/data/org/store/*` | Apple, Play |
| `secret/data/org/product/*` | admin Vendax, ArchFlow, … |
| `secret/data/customer/<tenant>/*` | já alinhado a targets de cliente |
| `secret/data/ci/*` | tokens de pipeline |

**Proibido** misturar segredo de cliente final e conta da loja Apple no mesmo objeto de UI sem labels e policy distintos.

### 3. Modo de entrega padrão: **checkout controlado** (não vault livre)

1. Operador/gestor autenticado no Manager  
2. Seleciona `OrgAccount`  
3. Informa **motivo** + **TTL** (default curto, ex. 1–2h)  
4. Contas **P0**: dual-control (segundo aprovador)  
5. Reveal / copy **uma vez** na sessão do browser (server-side fetch do OpenBao; nunca admin token no browser)  
6. Audit: principal, recurso, motivo, início, fim, IP  
7. Expiração / check-in encerra a janela  

Isso **ainda mostra** a senha em alguns casos (SaaS sem proxy), mas com identidade, TTL e trilha — padrão PAM enterprise, não LastPass livre.

### 4. Redução de senha compartilhada (estratégia paralela)

Onde a plataforma permitir, preferir:

- **GCP / Google:** usuários individuais + IAM; service accounts e chaves no OpenBao  
- **Play / Apple:** usuários individuais com roles; API keys no OpenBao; conta owner em dual-control  
- **Produtos próprios:** OIDC Kanidm; eliminar admin/senha local no fluxo feliz  

O broker governa o **que ainda é senha**; a estratégia de produto **elimina** senha compartilhada ao longo do tempo.

### 5. Browser via gateway (secundário)

Warpgate HTTPS / inject **apenas** onde o alvo for HTTP interno ou compatível.  
**Não** é o happy path para Google Cloud Console / Play / App Store Connect (SSO de provedor, anti-bot, device trust).

### 6. Invariantes (constituição)

| # | Invariante |
|---|------------|
| C1 | Token/root OpenBao **nunca** no browser |
| C2 | Connect **não** persiste senhas org no disco/keychain do app |
| C3 | Offboarding (via Manager) revoga login + fecha checkouts org |
| C4 | Toda reveal/checkout auditável |
| C5 | P0 exige dual-control ou waiver documentado |
| C6 | Inventário SoT no control plane, não planilha como verdade |
| C7 | **Console-only:** operação OCB/RBAC/secret write **não** exige UI/CLI de IdP ou OpenBao; se exigir, é gap de produto no Manager |

## Fases de entrega

| Fase | Entrega |
|------|---------|
| **OCB-0** | Inventário importável (YAML/CSV) + CRUD metadados sem secret value na UI de lista |
| **OCB-1** | OpenBao KV paths + write admin + checkout reveal TTL + audit |
| **OCB-2** | Dual-control P0 + notificações |
| **OCB-3** | Preferência API key / rotação assistida |
| **OCB-4** | Federar produtos (OIDC) — redução de contas password |
| **OCB-5** | (Opcional) tile Connect só leitura de *catálogo* + link Manager |

## Consequências

**+** Um lugar para contas da casa com policy e offboarding.  
**+** Reusa Manager, Kanidm, OpenBao, audit log.  
**+** Não dilui o bastion de cliente (Connect continua RDM de infra).  
**−** Reveal controlado ainda é superfície de copiar senha (mitigar com TTL, dual-control, preferir keys).  
**−** Não substitui 1Password pessoal para senhas *não* corporativas.  
**−** Integração Google/Apple “sem senha” depende de processo de IdP/loja, não só de código.

## Fora de escopo deste ADR

- Password manager completo (pastas pessoais, autofill browser, sync multi-device genérico)  
- Vault local no Connect  
- Substituir gestão IAM nativa do GCP/Apple (só orquestra e guarda break-glass)  
- Segredos de cartão / dado de cliente final no mesmo módulo sem classificação LGPD  

## Alternativas rejeitadas

| Alternativa | Motivo |
|-------------|--------|
| Só planilha + 1Password time | Sem RBAC Kanidm, sem audit unificado, offboarding manual |
| Vault só no Connect | Endpoint é o pior lugar; contradiz ADR-008 |
| Proxy browser para todo SaaS | Não funciona de forma confiável em GCP/Play/Apple |
| Misturar com targets de site | Confunde tenant de cliente com conta da IntegrAllTech |

## Aceite

- [x] Produto / security: dual-control P0 e lista inicial de contas (seed + UI)  
- [x] Ops: paths OpenBao `secret/data/org/…` + write/checkout server-side (app token)  
- [x] Eng: OpenSpec OCB-0…OCB-5 entregues no control plane  
- [x] A1 Offboarding: sessão expirada → 401; revoke person fecha checkouts org  
- [x] A2 Inventário P0 com `secret_ref`; sem senha em git/YAML (valores só OpenBao)  
- [x] A3 Este ADR marcado **Aceito** após implementação  

**Residual (não bloqueia aceite do ADR):**

| Item | Dono |
|------|------|
| OCB-4.4 clients OIDC em cada produto | squads de produto |
| Material secret real nos paths OpenBao (migração operacional) | ops / owners |
| Webhook Slack `ORG_CHECKOUT_WEBHOOK_URL` | ops (opcional) |

## Referências

- OpenSpec: `openspec/changes/add-org-credential-broker/`  
- Runbook: `documentos/runbooks/org-credential-broker.md`  
- Federação: `documentos/runbooks/org-product-oidc-federation.md`
