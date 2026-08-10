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

- [x] P0-01 concluído: Connect, orchestration e o deploy suportado usam ArchGuard-only; manifests, imagens, health checks e validações do runtime local legado foram removidos dos caminhos operacionais.
- [~] P0-02 a P0-06: deploy/smokes legados removidos, OpenSpec baseline atualizado, gate de licença/SBOM adicionado ao CI, idempotência integrada a contas/checkout, audit outbox transacional e forwarder HTTPS configurável implementados no ArchGuard Console (`f689061`); ainda falta operar um endpoint durável real e marcar todos os runbooks históricos.
- [x] W1-01 concluído: RustGuac implantado como gateway de sessões em `guac.archgate.com.br`, com Console → BFF → RustGuac validado.
- [x] W1-03/W1-04 concluídos: contrato de sessão e ticket WebSocket single-use formalizados em `rustguac-proxy.ts`, com TTL de 30s, URL sem credencial administrativa e testes unitários.
- [x] W1-05 concluído: sessão OIDC resolve `subject` no ArchGuard session-context, exige identidade ativa e anexa memberships autoritativas ao cookie server-side.
- [x] W1-06 adapter concluído: `checkOpenFga` envia tuple `user/relation/object` e falha fechado quando OpenFGA está habilitado.
- [x] W1-06 store/modelo OpenFGA provisionados na VPS; smoke sem tuple retorna `allowed=false`.
- [x] Sincronizador idempotente de tuples criado em `scripts/77-sync-openfga-tuples.sh` (arquivo root-only, sem permissões fictícias).
- [x] Materialização integrada ao Admin Console: grant escreve `connect`; offboarding remove as tuplas do principal.
- [x] W1-06 ativado em desenvolvimento com duas tuplas explícitas de laboratório para `uat-op-a`; produção permanece sem concessões implícitas.
- [x] W1-07 ponto de encerramento server-side criado em `DELETE /api/unified/v1/sessions/:sessionId`; RustGuac fecha a sessão sem expor a API key.
- [x] W1-07 `lease_id` real, quando fornecido pelo segredo, é persistido apenas server-side e revogado no encerramento.
- [x] W1-07 role dinâmica de laboratório configurada no OpenBao (`archgate-lab-readonly`), com TTL 15m/1h e revogação validada.
- [x] W1-07 targets podem optar por `openbao_database_role`; emissão server-side associa `lease_id` e o encerramento revoga a credencial.
- [x] W1-07 role dinâmica configurável no Admin Console (formulário de site e wizard), persistindo apenas o identificador da role.
- [~] W1-08 smoke SSH RustGuac interno concluído; smoke E2E autenticado de navegador foi adicionado em `tests/e2e/rustguac-session.spec.ts` (`e09ce3f`), mas aguarda `ARCHGATE_E2E_SESSION_COOKIE` e target de laboratório. O Playwright local também depende de uma instalação limpa de `node_modules`; build Docker passou.
- [~] W1-09 políticas de sessão: gravação, clipboard e intenção de drive agora são configuráveis por target no Admin Console e propagadas por sessão; transferência de arquivos permanece desligada no gateway de laboratório. Falta validação E2E no navegador e rollout controlado de upload/download.
- [~] W1-10 catálogo server-side de gravações RustGuac exposto em `GET /api/unified/v1/recordings`, protegido por `gateways:read`; playback autenticado passa por `GET /api/unified/v1/recordings/:name` e só aceita artefatos `.guac` de sessões broker conhecidas. Política de retenção/legal hold está disponível em `POST /api/unified/v1/recordings/:name/retention`; falta evidência E2E com uma gravação real e integração da remoção física no gateway.
- [x] W2-03 enrollment de connector concluído para laboratório: token hash-only, TTL de 60–3600s, vínculo site/connector, consumo atômico single-use, signing bridge, cliente CSR local no agent e emissão/revogação tenant-scoped no Manager.
- [~] W2-02 contrato de transporte documentado em `documentos/CONTRATO-CONNECTOR-OUTBOUND.md`: envelope versionado, mTLS, CSR, heartbeat, capabilities, backoff/idempotência e revogação; falta reconnect de stream/HA e ativação do router de produção.
- [~] W2-04 PKI de laboratório provisionada por `scripts/80-bootstrap-openbao-connector-pki.sh` no mount `pki-connectors`, com registro de serial e revogação no OpenBao; falta separar CA de produção e executar smoke com certificado revogado.
- [~] W2-02 transporte inicial no agent concluído: heartbeat HTTPS outbound com mTLS, envelope versionado, `message_id`, capabilities, estado `ready/degraded`, backoff exponencial com jitter e failover entre `CONNECTOR_HEARTBEAT_URLS`; falta reconnect de stream/HA completo.
- [~] W2-02 endpoint Manager de heartbeat concluído para edge opt-in: exige proxy mTLS confiável, certificado verificado e `connector_id` coincidente; persiste estado/capabilities/inventário e rejeita serial ausente, desconhecido ou revogado quando `CONNECTOR_MTLS_REQUIRE_CERT_REGISTRY=1`. Falta associar a opção a um router/domínio de produção.
- [~] W2-02 testes de heartbeat adicionados: persistência idempotente por connector e rejeição de versão/estado inválidos. Execução completa da suíte depende de restaurar as dependências locais do Console; o build Docker de produção permanece validado.
- [~] W2-04 lifecycle de certificados implementado no Manager: registro de serial, revogação via OpenBao e ação `rotate` com novo CSR/overlap (`67351e6`); o agente renova antes do expiry usando `CONNECTOR_ROTATION_TOKEN` (`4d963f4`). Falta fornecer token de rotação de laboratório e executar smoke E2E com certificado revogado.
- [~] W2-05 inventário limitado adicionado ao heartbeat e exposto por `GET /api/org/v1/connectors/inventory`, protegido por `sites:read`; histórico limitado a 100 snapshots por connector agora está disponível em `GET /api/org/v1/connectors/inventory/history`. Falta validar redaction em E2E.
- [~] W2-06 diagnóstico redigido disponível no Manager em `GET /api/org/v1/connectors/diagnostics` e no agent em `GET /v1/diagnostics`, com frescor do heartbeat, estado stale/revoked, capabilities, serial truncado e journal limitado a 100 linhas redigidas; falta validar operação com connectors reais.

### Próximos gates recomendados

1. Concluir P0-01/P0-04: retirar do runtime e marcar como superseded os artefatos legados ainda encontrados em `deploy/`, `openspec/` e `deploy/versions.env`.
2. Concluir W1-08 a W1-11 com E2E de navegador, RDP/VNC e aposentadoria da UI stock.
3. Fechar W2-02 a W2-04 com domínio/router mTLS, rotação, revogação e autorização tenant-scoped.
