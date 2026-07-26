# ADR-013 — Org Credential Broker (contas da IntegrAllTech)

- **Status:** Proposto (aguardando aceite de produto)
- **Data:** 2026-07-26
- **Relacionado:** [CONSTITUTION](../CONSTITUTION.md) §2 · [ADR-009](./ADR-009-control-plane-admin-console.md) Manager · [ADR-009A](./ADR-009A-archgate-manager-produto.md) · OpenBao (CP-4) · [ADR-008A](./ADR-008A-archgate-connect-cliente-operador.md) Connect (fora do happy path)
- **OpenSpec:** `openspec/changes/add-org-credential-broker/`

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

### 1. Novo módulo no **ArchGate Manager**: Org Accounts / Credential Broker

| Superfície | Papel |
|------------|--------|
| **ArchGate Manager** | Catálogo, checkout, aprovação, admin de contas org |
| **OpenBao** | SoT do material secreto (`secret/data/org/…`) |
| **Kanidm** | Quem pode ver / checkar / aprovar (grupos + permissions) |
| **ArchGate Connect** | **Não** é o vault; opcionalmente deep-link futuro só com role e sem storage local |

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
| C3 | Offboarding Kanidm revoga checkout e UI |
| C4 | Toda reveal/checkout auditável |
| C5 | P0 exige dual-control ou waiver documentado |
| C6 | Inventário SoT no control plane (PG), não planilha como verdade |

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

- [ ] Produto / security: dual-control P0 e lista inicial de contas  
- [ ] Ops: paths OpenBao e policy app token  
- [ ] Eng: OpenSpec `add-org-credential-broker` em implementação por ondas OCB-0…  

## Referências

- OpenSpec: `openspec/changes/add-org-credential-broker/`  
- Runbook (a criar na implementação): `documentos/runbooks/org-credential-broker.md`
