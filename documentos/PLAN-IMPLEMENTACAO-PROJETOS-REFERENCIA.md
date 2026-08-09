# Plano de implementação — aprendizados dos projetos de referência

| Campo | Valor |
|---|---|
| Status | Ativo |
| Início | 2026-08-07 |
| Objetivo | Incorporar os padrões úteis de RustGuac, Veyport, OneTerm, Remota, ThinkWatch e BastionDB sem duplicar ArchGuard, OpenFGA ou OpenBao |
| Control plane | Toda configuração suportada termina no **ArchGate Manager** |
| Identidade | **ArchGuard é o único IdP**; archguard não é suportado |

## Regras de execução

1. Código Apache-2.0 de RustGuac e Veyport pode ser reaproveitado com atribuição e revisão.
2. BastionDB, OneTerm e Remota (AGPL) e ThinkWatch (BUSL) são somente referência comportamental; nenhum código entra na árvore de build.
3. Cada capability precisa de API server-side, tela no Manager, autorização, auditoria e teste de isolamento.
4. Scripts são bootstrap/break-glass. Uma operação existente apenas em script não está completa.
5. Nenhum segredo administrativo ou credencial de alvo chega ao browser ou ao notebook.

## Caminho crítico

```text
P0 legado/contratos
  → W1 gateway de sessão
    → W2 connector outbound
      → W3 grants e políticas
        → W4 experiência do operador
          → W5 auditoria/operação
            → W6 hardening/GA
```

## P0 — Base coerente

**Critério de saída:** nenhum runtime suporta archguard; contratos ArchGuard/OpenFGA/OpenBao estão explícitos; Manager é a única superfície administrativa suportada.

| ID | Tarefa | Entrega | Aceite |
|---|---|---|---|
| P0-01 | Remover fallback archguard de clientes e orchestration | ArchGuard-only | Testes Go/Maven; busca de runtime sem fallback |
| P0-02 | Substituir deploy e smokes archguard | scripts ArchGuard | Warpgate, OpenBao, offboarding e isolamento passam com ArchGuard |
| P0-03 | Remover stack/imagens/health checks archguard | deploy limpo | nenhuma imagem, serviço ou variável `archguard_*` ativa |
| P0-04 | Atualizar OpenSpecs e documentos vivos | baseline coerente | archguard apenas em ADR/evidência histórica marcada como superseded |
| P0-05 | Definir contratos BFF do Manager | API de control plane | authz por ação, idempotency key, audit event e job assíncrono documentados |
| P0-06 | Criar license gate/SBOM | CI | AGPL/BUSL falham build; Apache NOTICE preservado |

## W1 — Gateway unificado de sessões

**Fonte principal:** RustGuac.  
**Critério de saída:** operador abre SSH e RDP na UnifiedUI sem UI stock, token administrativo ou credencial de alvo.

| ID | Tarefa | Entrega | Aceite |
|---|---|---|---|
| W1-01 | Spike RustGuac × arquitetura atual | decisão go/adapt/no-go | matriz de módulos, licença, acoplamentos e benchmark |
| W1-02 | ADR do gateway gráfico | fronteira aprovada | processo/biblioteca, ownership e migração definidos |
| W1-03 | Contrato `POST /sessions` | sessão comum | identity, org, grant, target, connector, policies e `pcid` |
| W1-04 | Ticket WebSocket single-use | broker seguro | TTL ≤60s; replay, audience errada e terceiro participante negados |
| W1-05 | Integração ArchGuard | OIDC/JWT | `org`, `mid`, `acr`, `sid`, `pcid` e logout validados |
| W1-06 | Autorização OpenFGA | decisão granular | fail-closed; razão e modelo versionado auditados |
| W1-07 | Credencial OpenBao server-side | lease por sessão | segredo não aparece no browser/log; revoke no encerramento |
| W1-08 | SSH/RDP/VNC via guacd | data plane | smokes reais e resize/reconnect |
| W1-09 | Clipboard/file/drive policies | DLP de sessão | copy, paste, upload e download independentes |
| W1-10 | Recording e playback | evidência | retenção, integridade e vínculo com sessão |
| W1-11 | Aposentar UI stock | happy path único | deep links externos removidos do fluxo normal |

## W2 — Connector outbound operável

**Fonte principal:** Veyport.  
**Critério de saída:** site é enrolled, observado, atualizado e revogado pelo Manager sem porta inbound.

| ID | Tarefa | Entrega | Aceite |
|---|---|---|---|
| W2-01 | Spike dos packages Veyport | matriz de reuso | certs, transport, heartbeat, sysinfo e update avaliados |
| W2-02 | Protocolo hub↔connector | contrato versionado | mTLS, reconnect, backoff, heartbeat e capabilities |
| W2-03 | Enrollment no Manager | fluxo completo | token single-use vira certificado ligado a tenant/site |
| W2-04 | Rotação e revogação | lifecycle | overlap, expiry, CRL/status e teste de connector revogado |
| W2-05 | Inventário automático | site runtime | SO, versão, interfaces, rotas, subnets e reachability |
| W2-06 | Diagnóstico e logs | operação | coleta limitada, redigida e auditada |
| W2-07 | Upgrade controlado | rollout | canal, versão alvo, progresso, rollback e assinatura |
| W2-08 | HA do hub | continuidade | reconnect sem duplicar sessão ou perder identidade |

## W3 — Grants e controles privilegiados

**Fontes:** OneTerm como referência; ArchGuard/OpenFGA como implementação.

| ID | Tarefa | Entrega | Aceite |
|---|---|---|---|
| W3-01 | Modelo de grant temporário | domínio | janela, justificativa, ticket, aprovadores e expiração |
| W3-02 | Workflow de aprovação | Manager | step-up, dual control opcional e trilha completa |
| W3-03 | Materialização OpenFGA | policy plane | outbox/reconciliação; indisponibilidade falha fechada |
| W3-04 | Command policies SSH | enforcement | allow/deny/approval; comando e resultado auditados |
| W3-05 | Quick commands aprovados | catálogo | versionamento, parâmetros validados e RBAC |
| W3-06 | Compartilhamento de sessão | colaboração | viewer/controller, TTL, revogação e presença visível |
| W3-07 | Recertificação de acesso | governança | campanhas e remoção automática de grants vencidos |

## W4 — Experiência do operador

**Fonte:** padrões de UX do Remota, sem vault local de credenciais.

| ID | Tarefa | Entrega | Aceite |
|---|---|---|---|
| W4-01 | Catálogo hierárquico | UnifiedUI/Connect | cliente→site→ambiente→conexão; busca, tags, favoritos |
| W4-02 | Herança não secreta | configuração | políticas/display/gateway herdáveis; nenhum password/key |
| W4-03 | Sessões em abas | workspace | SSH/RDP/VNC/Web simultâneos, estado e tempo do grant |
| W4-04 | Deep links | Connect | `archgate://connect/<id>` sem token na URL |
| W4-05 | Importadores | onboarding | CSV/JSON/OpenSSH/mRemoteNG apenas metadados |
| W4-06 | Soft-delete/lixeira | Manager | restore, dependências, purge e step-up para definitivo |
| W4-07 | CLI com contexts | automação | keychain, `--json`, exit codes e mesmas APIs do Manager |

## W5 — Segurança, auditoria e operação

**Fontes:** ideias de ThinkWatch e BastionDB, implementadas internamente.

| ID | Tarefa | Entrega | Aceite |
|---|---|---|---|
| W5-01 | API keys/service accounts scoped | Manager + ArchGuard | hash, TTL, rotation, last-used, audience e revocation |
| W5-02 | Security linter | CI/startup/Manager | RLS, tenant scope, issuer, audience, redirects e TTLs |
| W5-03 | Resolver de client IP | middleware comum | proxies confiáveis, IPv4/IPv6 e testes de spoofing |
| W5-04 | Audit outbox | pipeline durável | evento transacional, retry, DLQ e idempotência |
| W5-05 | Encadeamento/selagem | trilha verificável | verificador e alerta de lacuna no Manager |
| W5-06 | Forwarders SIEM | syslog/webhook/Kafka | redaction, assinatura, retry e lag visível |
| W5-07 | Health semântico | live/ready/detail | dependências e degradação corretas |
| W5-08 | Métricas protegidas | Prometheus | token/rede interna e labels sem alta cardinalidade |
| W5-09 | Retenção/legal hold | policy | audit, recordings, transcript, files e crypto-shredding |
| W5-10 | Canaries controlados | detecção | alerta forte; sem blacklist permanente automática por IP |

## W6 — Resiliência e GA

| ID | Tarefa | Entrega | Aceite |
|---|---|---|---|
| W6-01 | Backup por datastore | rotina | RPO medido; inclui material criptográfico necessário |
| W6-02 | Restore automatizado | runbook/teste | ambiente isolado restaurado e smoke funcional |
| W6-03 | DR drill trimestral | governança | RTO real registrado no Manager |
| W6-04 | Rotação de segredos/chaves | workflows | overlap, `kid`, certificado connector e verificação pós-roll |
| W6-05 | Testes authz horizontais/verticais | release gate | tenant crossing, role, acr, grant, audience, replay e logout |
| W6-06 | Performance/capacity | baseline | conexões concorrentes, gravação e reconnect medidos |
| W6-07 | GA checklist | aceite | zero configuração rotineira fora do Manager |

## Primeira sequência executável

1. `P0-01` — remover fallback archguard do runtime.
2. `W1-01` — concluir spike RustGuac.
3. `W1-02` — decidir arquitetura.
4. `W1-03` e `W1-04` — contrato de sessão e ticket single-use.
5. `W1-05` a `W1-07` — identidade, autorização e segredo.
6. `W1-08` — primeiro SSH real; depois RDP.

## Progresso

- [x] P0-01 iniciado: Connect e orchestration passaram a ArchGuard-only; testes Go e Maven registrados em 2026-08-07.
- [ ] P0-02 a P0-06.
- [x] W1-01 concluído: RustGuac implantado como gateway de sessões em `guac.archgate.com.br`, com Console → BFF → RustGuac validado.
- [x] W1-03/W1-04 concluídos: contrato de sessão e ticket WebSocket single-use formalizados em `rustguac-proxy.ts`, com TTL de 30s, URL sem credencial administrativa e testes unitários.
- [x] W1-05 concluído: sessão OIDC resolve `subject` no ArchGuard session-context, exige identidade ativa e anexa memberships autoritativas ao cookie server-side.
- [x] W1-06 adapter concluído: `checkOpenFga` envia tuple `user/relation/object` e falha fechado quando OpenFGA está habilitado.
- [x] W1-06 store/modelo OpenFGA provisionados na VPS; smoke sem tuple retorna `allowed=false`.
- [x] Sincronizador idempotente de tuples criado em `scripts/77-sync-openfga-tuples.sh` (arquivo root-only, sem permissões fictícias).
- [x] Materialização integrada ao Admin Console: grant escreve `connect`; offboarding remove as tuplas do principal.
- [x] W1-06 ativado em desenvolvimento com duas tuplas explícitas de laboratório para `uat-op-a`; produção permanece sem concessões implícitas.
- [x] W1-07 ponto de encerramento server-side criado em `DELETE /api/unified/v1/sessions/:sessionId`; RustGuac fecha a sessão sem expor a API key.
- [ ] W1-07 associar `lease_id` OpenBao dinâmico ao ciclo da sessão (KV estático não será tratado como lease).
