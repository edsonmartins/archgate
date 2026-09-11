# Auditoria de prontidão para homologação — 2026-09-07

**Parecer: NÃO APTO para liberar esta revisão como candidata à homologação formal.** Há implementação relevante e componentes compiláveis, mas permanecem falhas comprovadas de autorização, ciclo de vida de acesso e qualidade da release. Aprovação histórica de laboratório não cobre a revisão atual nem substitui esses controles.

## Escopo e método

| Repositório local | Revisão examinada | Responsabilidade |
|---|---|---|
| `archgate` | `e0e75f7` | Serviços Java, plugin Oracle, CLI Go, desktop Tauri, UnifiedUI, especificações e evidências |
| `_archguard` | `c2f03ee` | Console Manager, BFF, RBAC, sessões, conectores, auditoria e broker |
| `archgate-devops` | `34b58cc` | Compose, deploy, conectores e recuperação |

As três árvores estavam limpas no início. Foram inspecionados os fluxos críticos e executados testes/builds locais, consultas de CI, consultas públicas HTTP/OIDC e análise de dependências. As reproduções de autorização utilizaram os handlers reais com integrações externas simuladas, em cópias temporárias. Nenhuma conta, permissão, sessão real ou infraestrutura foi alterada. Este relatório não implementa as correções.

**Limites:** não foi realizado pentest do ambiente, inspeção SSH da VPS, UAT autenticado com usuários reais, restauração real de backups ou acesso a redes/bancos de clientes. O código interno do IdP hospedado não foi auditado; foram examinados seus consumidores e discovery público. Não foi feita varredura completa de segredos no histórico Git, de CVEs Java/Go/Rust ou das imagens implantadas. Não há evidência de que os SHAs locais sejam os mesmos em execução na VPS.

Classificação: **P0** = bloqueio de segurança/isolamento; **P1** = bloqueio funcional, operacional ou de qualidade da candidata; **P2** = residual que pode sair do escopo inicial explicitamente. “Reproduzido” significa execução local controlada; “código” significa análise do caminho de execução; “a validar” não é apresentado como falha observada em produção.

## Resultado das verificações

| Verificação | Resultado em 07/09 |
|---|---|
| Orchestration — `mvn test` | 25 testes, zero falhas |
| Oracle proxy — `mvn test` | 7 testes, zero falhas; caminho mock |
| Agent control — `mvn test` | 18 testes, zero falhas |
| Connect CLI — `go test ./...` | PASS; testes em cli/config/oidc; outros pacotes sem testes |
| Plugin OpenBao Oracle — `go test ./...` | Compila, mas todos os pacotes retornam `[no test files]` |
| UnifiedUI — instalação e `npm run build` | PASS |
| Desktop — instalação e `npm run build` | PASS após reinstalar dependências locais incompletas |
| Desktop Rust — `cargo check --locked` | PASS em macOS ARM64; não equivale a instalador assinado nem teste da interface |
| Connector agent — `python3 -m unittest discover -s .../tests -v` | 3 testes, zero falhas; contratos simulados |
| Shell — `bash -n` em deploy/clients/scripts | PASS |
| Shellcheck — severidade error em deploy/clients | PASS |
| License gate — `bash scripts/license-gate.sh` | FAIL local: exclusões não filtraram o próprio script e documentos quando pesquisou pelo caminho absoluto; falso positivo, não evidência de licença proibida |
| Console — `npm ci`, Node 22.23.1/npm 10.9.8 | FAIL: faltam `chokidar`, `lru-cache` e `readdirp` no lock para essa resolução |
| Console — mesmo lock, npm 11.19/Node 22 + SQLite nativo preparado | Instalação viável; build PASS com avisos de módulos server-side no grafo cliente |
| Console — typecheck com versões exatas do lock | FAIL; continua falhando depois de o build regenerar a árvore de rotas |
| Console — suíte original com versões exatas | 259 PASS / 4 FAIL, 35 arquivos |
| Reproduções adicionais de autorização/lifecycle | 3/3 reproduziram os defeitos; não estão contabilizadas nos 263 testes originais |
| Contrato plugin Oracle → renderer Java | Reproduzido: 2 comandos viram 4 statements |
| HTTP público sem autenticação | Console 307; bootstrap operador 401; Guac 200, TLS sem bypass |
| Discovery público ArchGuard | Consultado; endpoints diferem dos montados pela UnifiedUI |

Os quatro testes originais que falham são dois de `idp-discovery.test.ts` (expectativas do caminho legado) e dois de `rustguac-proxy.test.ts` (mock HTTP 204 com corpo e configuração capturada antes da preparação). Eles não provam indisponibilidade real do IdP ou RustGuac, mas impedem afirmar que a suíte está verde.

Uma resolução exploratória de dependências na primeira cópia temporária também falhou no build com proteção de imports server-side. Como ela atualizou versões, esse resultado **não é atribuído ao lock original**. A tabela acima usa a segunda cópia, com versões exatas: TanStack Start 1.160.2, Vite 7.3.1, Vitest 3.2.4 e better-sqlite3 12.9.0.

As últimas execuções consultadas no GitHub estavam verdes para commits anteriores: [CI ArchGate em `f8d4bdeb`](https://github.com/edsonmartins/archgate/actions/runs/31230298789) e [CI ArchGuard em `c7165c42`](https://github.com/edsonmartins/archguard/actions/runs/31229070616), ambas de 08/08. Não validam os SHAs locais acima.

## Achados bloqueantes de segurança

### A01 — P0 — Tenant admin pode escalar privilégios e atuar fora do tenant — REPRODUZIDO

O tenant admin recebe `persons:update/create`. `provisionPersonAccessFn` aceita `groups` e `tenant_slug` do solicitante e chama o IdP sem restringir grupos administrativos ou conferir o tenant do principal-alvo. O mesmo problema de escopo existe em grant e offboarding.

Na reprodução, uma sessão de admin Rio conseguiu encaminhar a inclusão de si própria em `archguard_super_admins` e `tenant_grupo_marra`; também conseguiu vincular uma role Marra e desabilitar um usuário Marra. A permissão real do handler foi preservada; apenas IdP/WG/HTTP foram simulados. O efeito no ambiente depende dos privilégios da service account configurada.

Evidências: [lifecycle-fn.ts:64](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/lifecycle-fn.ts:64), [grant:386](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/lifecycle-fn.ts:386), [offboarding:120](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/offboarding-fn.ts:120), [permissões:100](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/lib/auth/permissions.ts:100).

**Concluir:** autorização server-side por ação, tenant e principal; allowlist de grupos delegáveis; proibir concessão de privilégio superior ao do solicitante. **Aceite:** requests diretos de tenant admin para grupos de plataforma, outro tenant ou usuário externo recebem 403 antes de qualquer chamada externa.

### A02 — P0 — Gravações e auditoria sem isolamento suficiente — CÓDIGO

Listagem e download de gravações exigem `gateways:read`, disponível ao tenant admin, mas não filtram pelo proprietário/tenant. O download verifica existência no broker, não autorização sobre aquela sessão. A timeline de auditoria aceita inclusive `persons:read`, presente em operador/viewer, e consulta o log global e sessões WG sem filtro de tenant.

Evidências: [recordings.ts:25](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/routes/api/unified/v1/recordings.ts:25), [download:21](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/routes/api/unified/v1/recordings.$name.ts:21), [timeline:42](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/unified-audit-fn.ts:42).

**Concluir:** vincular gravação/evento a tenant, principal e autorização; filtrar no servidor; separar `audit:read` de leitura de pessoas. **Aceite:** usuário A não lista nem baixa gravações/eventos B, inclusive por identificador conhecido.

### A03 — P0 — Revogação central não invalida todos os acessos existentes — CÓDIGO / E2E PENDENTE

O guard de cookie verifica autenticação e expiração locais, sem consultar revogação do principal. O offboarding não invalida esses cookies nem fecha sessões RustGuac. `broker_sessions` guarda apenas sessão, lease e datas, sem principal/tenant; falta o vínculo necessário para encerramento seletivo. O DELETE de sessão apenas autentica o solicitante e fecha o ID informado, sem verificar propriedade. Não foi demonstrado que excluir o usuário WG encerra todas as conexões já abertas.

Evidências: [session-guard.ts:19](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/session-guard.ts:19), [broker_sessions:161](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/db.ts:161), [DELETE:14](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/routes/api/unified/v1/sessions.$sessionId.ts:14).

**Concluir:** identidade canônica nas sessões, invalidadores server-side, encerramento por principal em cada gateway e autorização de fechamento. **Aceite:** após offboarding, cookie/token anterior deixa de operar, SSH/DB/browser ativos caem dentro de prazo definido, novas sessões falham e outro usuário continua conectado. O UAT atual testa principalmente novo login e precisa incluir sessões já abertas.

### A04 — P0 — Offboarding OpenBao tem alcance global — CÓDIGO, CONDICIONAL AO ADAPTADOR LIVE

`revokeAll(username)` envia duas vezes a revogação do prefixo global `database/creds`, sem relacioná-lo ao usuário. Com o adaptador habilitado e credencial suficiente, um offboarding pode revogar leases de todos os clientes. `grantAccess` também gera ACLs com wildcard para credenciais dinâmicas, estáticas e segredos de todos os targets; target/TTL aparecem apenas no comentário da policy.

Evidência: [OpenBaoLiveAdapter.java:29](/Volumes/DevCache/desenvolvimento/archgate/services/orchestration/src/main/java/br/com/integralltech/archgate/orchestration/adapter/OpenBaoLiveAdapter.java:29).

**Concluir:** inventário de leases por principal/tenant/sessão, revogação individual e ACL de menor privilégio. **Aceite:** revogar A invalida somente os leases A, com B conectado e funcional; grant para um target não permite ler outro.

### A05 — P0 — Cache de idempotência persiste e reentrega segredos do broker — CÓDIGO

O checkout de conta corporativa coloca senha/API key na resposta e a passa integralmente a `completeIdempotency`, que grava JSON em SQLite sem criptografia da aplicação. O replay retorna essa resposta antes de revalidar status/TTL do checkout. A tabela não aplica prazo de expiração da resposta. Isso amplia a custódia dos segredos para banco/backups do console e permite recuperar a resposta depois do encerramento do checkout, enquanto a sessão ainda autoriza a chamada.

Evidências: [checkout:77](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/routes/api/org/v1/accounts.$id.checkout.ts:77), [persistência da resposta:193](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/routes/api/org/v1/accounts.$id.checkout.ts:193), [bff-idempotency.ts:51](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/bff-idempotency.ts:51).

**Concluir:** armazenar apenas metadados não secretos; revalidar acesso/checkout no replay e resolver segredo somente quando permitido. **Aceite:** senha sintética não aparece no SQLite; replay após checkin/expiração retorna negação. Este achado independe da exceção funcional do broker corporativo permitir revelar segredo: o problema é persistência/replay fora do controle do checkout.

## Correções funcionais e operacionais

| ID / prioridade | Problema e evidência | Conclusão exigida / aceite |
|---|---|---|
| A06 / P1 | **Provisionamento e offboarding reportam falha após sucesso.** `bindGroup` produz `idp_group`, mas o sucesso procura `archguard_group`; disable produz `idp`, mas procura `archguard`. Reproduzido com todas as integrações retornando sucesso. Também há tratamento de `partial` como `ok`. [Provision:138](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/lifecycle-fn.ts:138), [offboard:181](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/offboarding-fn.ts:181). | Unificar contrato de resultados; discriminar sucesso, parcial e falha; retorno/auditoria devem refletir efeito real. Testar falha individual de cada componente, não somente sucesso mock. |
| A07 / P1 | **TTL prometido não governa o grant real.** O bind direto WG recebe só usuário/role, não prazo; a tupla OpenFGA também não tem expiração. TTL segue para orquestração best-effort e log. [Bind:265](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/lifecycle-fn.ts:265). | Persistir concessão temporária e impor/reconciliar expiração. Aceite: grant curto deixa de permitir novas conexões automaticamente; falha/restart do worker não perpetua acesso. |
| A08 / P1 | **OpenFGA usa identidades diferentes.** Grant/revoke usam `user:<username>`; sessão consulta preferencialmente `user:<id/sub>`. O check ocorre no ramo RustGuac; é opcional por flag. Exclusão de grants lê uma página sem continuation token. [Grant:331](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/lifecycle-fn.ts:331), [check:186](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/unified-bff.ts:186), [OpenFGA:95](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/openfga.ts:95). | Adotar subject canônico, cobrir todos os caminhos incluídos na release e paginar revogação. Aceite com username diferente de sub, grants numerosos e indisponibilidade OpenFGA. O efeito exato depende da configuração/modelo implantados. |
| A09 / P1 | **Release sem gate local verde.** Lock depende da versão npm; typecheck falha; quatro testes falham; CI consultada é de SHAs anteriores. Persistem `gateways:update` inexistente, tipos `unknown`, incompatibilidade `artifact_url/url` e `vi` sem import. [CI console](/Volumes/DevCache/desenvolvimento/_archguard/.github/workflows/ci.yml), [retenção:27](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/routes/api/unified/v1/recordings.$name.retention.ts:27). | Fixar Node/npm, regenerar lock de forma revisada, corrigir código/testes e tornar geração de rotas reproduzível antes do typecheck. CI completa no SHA congelado; incluir desktop e integração do IdP atual. |
| A10 / P1 | **UnifiedUI não fecha autenticação real.** Monta `/authorize` e `/token`; discovery público informa `/login/oauth/authorize` e `/api/login/oauth/access_token`. Em falha do catálogo, inclusive 401/403, cai para mock. Logout limpa apenas sessionStorage. [oidc.ts:40](/Volumes/DevCache/desenvolvimento/archgate/frontend/unified-ui/src/auth/oidc.ts:40), [catalog.ts:30](/Volumes/DevCache/desenvolvimento/archgate/frontend/unified-ui/src/api/catalog.ts:30). | Consumir discovery; eliminar fallback mock da build de homologação; logout invalidar sessão BFF. Aceite: login/logout/expiração/catálogo com OIDC real e negação explícita quando backend rejeita. Fallback mock não foi interpretado como bypass do BFF. |
| A11 / P1; segurança bloqueante se Oracle incluído | **Oracle ainda não tem caminho real fechável.** Dockerfile empacota sem `-Pojdbc`, embora driver só exista nesse profile. Plugin envia aliases e `cmd_N`; renderer coleta todos, duplicando SQL (2→4 reproduzido). Rotação usa literal `ORACLE_ADMIN`, sem atualizar credencial JDBC. Proxy direto não tem agendador de expiração, API não possui autenticação de aplicação e mTLS é profile opcional não conectado no Compose examinado. Console devolve senha ao browser, com fallback direto sem lease. [Dockerfile:6](/Volumes/DevCache/desenvolvimento/archgate/services/oracle-proxy/Dockerfile:6), [plugin:220](/Volumes/DevCache/desenvolvimento/archgate/services/openbao-oracle-plugin/oracle/database.go:220), [renderer:25](/Volumes/DevCache/desenvolvimento/archgate/services/oracle-proxy/src/main/java/br/com/integralltech/archgate/oracleproxy/service/StatementRenderer.java:25), [Oracle UI API:169](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/oracle-fn.ts:169). | Decidir se Oracle integra a candidata. Se sim: driver na imagem, contrato ordenado sem duplicação, autenticação obrigatória, lease/cleanup/rotação real e injeção no gateway sem entregar credencial de alvo ao principal. Aceite em Oracle descartável incluindo expiração e falha parcial. Se não: retirar fluxo da experiência homologável e registrar exclusão. |
| A12 / P1 | **Connector mTLS não está integrado de ponta a ponta.** Handler confia em headers de proxy; arquivo TLS não está anexado a router. Script 81 apenas copia CA/opção e imprime ENABLED, sem implementar roteamento/injeção de identidade. Registry é opcional. Enrollment consulta sites no SQLite diretamente, enquanto SoT pode ser PG. Revoke valida connector, mas não associa o serial solicitado àquele connector; rotate também aceita serial anterior sem conferir essa associação. [heartbeat:12](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/routes/api/org/v1/connectors.heartbeat.ts:12), [enrollment:25](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/routes/api/org/v1/connectors.enrollment.ts:25), [script 81](/Volumes/DevCache/desenvolvimento/archgate-devops/scripts/81-install-connector-mtls-edge.sh). | Fechar endpoint mTLS exclusivo com headers sobrescritos, identidade derivada do certificado e bloqueio pelo endpoint público; usar repositório SoT comum; vincular serial a connector/tenant. Aceite com certificado errado/revogado, spoof de headers e rotação real. Não foi testado ataque ao proxy público. |
| A13 / P1 | **Rollout de connector chama stage com contrato incorreto.** Seleciona `{version, artifact_url, sha256}` e passa onde é esperado `{version, url, sha256}`. Typecheck confirmou. [connector-fn.ts:717](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/connector-fn.ts:717). | Mapear contrato, testar stage/apply/rollback em connector descartável e tratar retomada de plano interrompido. |
| A14 / P1 | **Restore pode declarar PASS após erro.** `pg_restore ... \| tail -20 || true` suprime a falha; listar tabelas não prova restauração válida. Backup de recordings contempla WG/Guacamole legado, não os paths separados RustGuac. [restore:48](/Volumes/DevCache/desenvolvimento/archgate-devops/scripts/backup-restore-dry-run.sh:48), [backup](/Volumes/DevCache/desenvolvimento/archgate-devops/scripts/backup-archgate-recordings.sh). | Propagar exit code, validar dados/contagens e exercitar restauração isolada. Cobrir gravações atuais, SQLite, PG, OpenBao e configuração necessária para recuperação; comprovar RPO/RTO e retenção acordados. Não executar o restore atual contra ambiente compartilhado sem isolar o destino fixo. |
| A15 / P1 se encaminhamento faz parte do aceite | **Outbox pode ficar parada após crash.** Claim marca `publishing`; futuras leituras pegam apenas pending/failed, sem timeout para recuperar publicação abandonada. Forwarder é acionado por novos eventos, sem worker periódico encontrado. [audit-outbox.ts:15](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/audit-outbox.ts:15), [activity-log.ts:81](/Volumes/DevCache/desenvolvimento/_archguard/archguard-console/src/server/activity-log.ts:81). | Lease/lock recuperável, retry periódico e deduplicação no destino. Aceite: matar processo após claim, reiniciar e publicar o evento uma vez logicamente. Log local não equivale a encaminhamento garantido. |
| A16 / P1 | **Orquestração ainda simula efeitos considerados concluídos.** `syncTenants()` retorna lista de passos sem chamar Axis/IdP/SoT; idempotência Java e resultados ficam em memória. Adapters desabilitados/dry-run podem retornar sem efeito e serem contabilizados como sucesso. [LifecycleService.java:149](/Volumes/DevCache/desenvolvimento/archgate/services/orchestration/src/main/java/br/com/integralltech/archgate/orchestration/service/LifecycleService.java:149), [HttpLiveAdapter:38](/Volumes/DevCache/desenvolvimento/archgate/services/orchestration/src/main/java/br/com/integralltech/archgate/orchestration/adapter/HttpLiveAdapter.java:38). | Contratos reais, estado durável, reconciliação e status explícito de simulação. Aceite com APIs reais de teste, retry e restart, sem duplicar concessões ou esconder revogação parcial. |

## Dependências, escopo residual e evidências de aceite

**A17 / P1 — Dependências exigem triagem antes da release.** `npm audit --package-lock-only` em 07/09 informou 33 dependências sinalizadas no console (4 critical, 18 high, 7 moderate, 4 low) e 5 na UnifiedUI (4 high, 1 moderate). São contagens da ferramenta, incluindo transitivas e ferramentas de desenvolvimento, não número de falhas exploráveis em produção.

Exemplo verificado na fonte primária: Vitest 3.2.4 está no intervalo afetado por [GHSA-5xrq-8626-4rwp](https://github.com/vitest-dev/vitest/security/advisories/GHSA-5xrq-8626-4rwp); o aviso condiciona impacto ao servidor UI/API exposto ou UI/Browser Mode no Windows. O alerta de [React Router RSC](https://github.com/remix-run/react-router/security/advisories/GHSA-qwww-vcr4-c8h2) não demonstra exposição da SPA atual, que não foi observada usando RSC. Separar build/dev/runtime, atualizar o que é aplicável e documentar as exclusões com evidência. Não usar `audit fix --force` como substituto de revisão.

**A18 / P1 ou P2 conforme plataformas contratadas — Distribuição do Connect.** Desktop compila em macOS, mas o manifesto gera apenas dmg/app; Developer ID/notarização real, Windows/Linux e RDP em Windows real continuam sem aceite. O CSP está `null`; comandos PTY merecem revisão da fronteira entre conteúdo remoto e comandos nativos. Não foi demonstrada exploração dessa superfície. O aceite deve ocorrer em máquina limpa do homologador. Referências: [tauri.conf.json](/Volumes/DevCache/desenvolvimento/archgate/clients/archgate-connect/desktop/src-tauri/tauri.conf.json), [tasks desktop](/Volumes/DevCache/desenvolvimento/archgate/openspec/changes/add-connect-embedded-sessions/tasks.md).

**A19 / P2 fora do MVP, P1 se vendido como parte dele — HA, agêntico e protocolos futuros.** Agent control retorna lease e execução mock; política/HITL em testes não prova ação no gateway. HA real, failover, consentimento e SA live continuam pendentes. Kubernetes, NetBird e protocolos sem ambiente de teste podem ficar fora da candidata com escopo explícito. Não é necessário concluir toda a fase 5 para homologar o MVP. Referências: [AgentControlService:95](/Volumes/DevCache/desenvolvimento/archgate/services/agent-control/src/main/java/br/com/integralltech/archgate/agentcontrol/service/AgentControlService.java:95), [tasks fase 5](/Volumes/DevCache/desenvolvimento/archgate/openspec/changes/add-agentic-access/tasks.md).

**A20 / P1 — Evidências e arquitetura não descrevem uma única candidata.** README/matriz/planos misturam Swarm lab, Compose VPS, IdP antigo/atual, Guacamole legado e RustGuac. O Compose põe Guacamole em profile legado; RustGuac permanece documentado como avaliação e proibido para sessões de cliente. A integração no console já existe, mas o pacote de avaliação ainda deixa ticket/replay/recording/decisão em aberto. É preciso concluir a decisão sobre o gateway browser incluído na homologação.

O [relatório Rio de 25/07](/Volumes/DevCache/desenvolvimento/archgate/documentos/evidence/smoke-evidence-2026-07-25-rio-quality-auto.md) declara PASS com 11 PASS e **10 SKIP**, incluindo SSH/PG profundos, peer remoto, Oracle e assinatura. O [closeout Connect](/Volumes/DevCache/desenvolvimento/archgate/documentos/evidence/2026-07-20-connect-residual-closeout.md) ainda lista credenciais PG reais, conta Forti institucional e um dia de uso sem VPN pessoal como não concluídos. Há evidências históricas de provisionamento/conectividade, portanto não se conclui que nada real foi feito; falta uma rodada completa e rastreável à candidata atual.

Referências: [plano formal:314](/Volumes/DevCache/desenvolvimento/archgate/documentos/PLAN-HOMOLOGACAO-MVP.md:314), [spike RustGuac](/Volumes/DevCache/desenvolvimento/archgate-devops/docs/RUSTGUAC-SPIKE.md), [tasks de avaliação](/Volumes/DevCache/desenvolvimento/archgate/openspec/changes/evaluate-rustguac-session-gateway/tasks.md).

## Ordem de fechamento recomendada

| Ordem | Entrega / responsável técnico sugerido | Critério de saída |
|---|---|---|
| 1 | Segurança do BFF — equipe console/identidade | A01–A05 corrigidos; testes negativos A/B, escalada, replay e sessão antiga sem efeito externo indevido |
| 2 | Ciclo de vida — console + orchestration/gateways | A06–A08/A16; grant/expiração/offboard com identidade canônica, revogação seletiva e estado reconciliável |
| 3 | Candidata reproduzível — mantenedores + CI | A09/A17; instalação, typecheck, testes e builds verdes no mesmo SHA; imagens por digest e matriz de versões |
| 4 | Escopo funcional — produto + responsáveis dos módulos | Resolver A10–A13; Oracle/browser/plataformas ou funcionam de ponta a ponta ou ficam explicitamente fora da candidata |
| 5 | Operação — DevOps | A14/A15; restore isolado validado, monitoramento/alerta de falhas, tokens mínimos, flags mock/lab desligadas para dados reais, mTLS/rotação comprovados se incluídos |
| 6 | Pré-UAT — QA + operação do piloto | Rodada atual de login real, catálogo, SSH/DB/browser incluídos, isolamento A/B, offboarding ativo, gravação/replay e recuperação |
| 7 | Homologação — revisor de negócio/técnico designado | Executar roteiro com a candidata congelada, registrar bugs e emitir aceite/rejeição humana com escopo e ressalvas datadas |

**Gate para ENTRAR em homologação:** zero P0 aberto; P1 do caminho contratado resolvidos; release instalável e reproduzível; ambiente/dados de teste preparados; evidências técnicas da mesma revisão; nenhum obrigatório do pré-UAT substituído por mock ou SKIP. Pendências externas fora do escopo precisam constar expressamente na candidata.

**Gate para SAIR homologado:** UAT humano executado e resultado registrado, com evidências, responsável, revisão/digests e ressalvas aceitas. A assinatura não é pré-requisito circular para começar o UAT; é seu resultado.

A pré-validação de segurança deve incluir MFA/step-up no IdP e nas ações privilegiadas, desativação das entradas de laboratório, negação após revogação e ausência de credenciais de alvo no tráfego do operador. Não foi obtida evidência atual suficiente desses cenários para considerá-los concluídos.

## Reproduções e rastreabilidade

As reproduções locais ficaram em `/private/tmp/archgate-audit-20260907.2hyc6A/`: `console-locked/tests/unit/server/audit-lifecycle-reproduction.test.ts` e `OracleContractAudit.java`. Não precisam de credenciais reais. A primeira usa handlers reais e permissão derivada de `archguard_tenant_admins`; confirma chamadas indevidas ao IdP/WG e status incorretos. A segunda chama `StatementRenderer` compilado com o formato de mapa produzido pelo plugin e confirma duplicação de statements. Estes arquivos temporários podem desaparecer; cópias das reproduções acompanham este relatório em `evidencias/`.

Não foi atribuída porcentagem de conclusão: o resultado de testes mock e o volume de checkboxes não permitem estimar maturidade de segurança nem esforço restante. O avanço deve ser medido pelos gates e cenários acima.

## Atualização de execução — 08/09/2026

Emissão concorrente RustGuac: a criação verifica bloqueio na entrada e registra a sessão emitida antes de verificar novamente o principal. Bloqueio observado após emissão aciona cleanup da sessão e do lease, sem devolver o ticket como sucesso. Typecheck, seis testes focados de broker (incluindo usuário bloqueado durante emissão e usuário não bloqueado) e build aprovados. A garantia depende de os processos consultarem o mesmo SQLite; não constitui validação distribuída nem cobre todos os gateways. Reativação segura permanece pendente de corte temporal/versionamento das sessões e tokens anteriores.

Rodada complementar de encerramento: falha no RustGuac não impede mais a tentativa de revogar o lease exato da sessão. Ambas as operações são tentadas; falhas mantêm o registro pendente para retry. Sessões desconhecidas são recusadas antes de chamadas externas. O resultado do offboarding agora distingue `login_blocked` de `ok/all_ok`; `partial` da orquestração não é aceito como sucesso, e a mensagem existente na tela informa revogação incompleta. Validação: typecheck e 269 testes em 37 arquivos aprovados, incluindo falhas independentes dos dois serviços e retry. Reativação pela tela, concorrência com emissão de sessões e revogação integral de todos os gateways permanecem pendentes; não houve deploy nem validação E2E real nesta rodada.

Revisão complementar: a primeira correção A05 negava replay, mas ainda persistia o segredo em `response_json`. Corrigido para persistir somente a resposta sanitizada em ambas as colunas, com teste de regressão. Isso protege novos registros; registros/backups antigos ainda exigem saneamento controlado. O contrato Oracle anterior também descartava comandos intermediários: agora transmite todos em ordem por uma única chave `sql`, testada no plugin.

Offboarding passou a persistir bloqueio local por username, consultado no cookie, refresh e autenticação bearer, e a tentar fechar cada sessão RustGuac registrada para esse usuário. Teste confirma persistência após reabrir o banco e preservação de outro usuário. Limitações ainda bloqueantes: identidade canônica, múltiplas réplicas com SQLite separado, sessões antigas sem proprietário, reativação administrativa pela tela, testes de sessão concorrente e encerramento nos demais gateways. O status de sucesso do offboarding ainda deve distinguir login bloqueado de revogação integral.

OpenBao: removidas chamadas ao prefixo global compartilhado. O adaptador remove a policy e informa falha parcial pela ausência de inventário individual de leases. Isso contém a revogação de terceiros, mas não conclui A04: permanecem inventário, ACL mínima e limpeza seletiva comprovada. Nenhuma implantação em produção foi realizada nesta rodada.

Foi iniciada a correção dos bloqueios diretamente ligados ao caminho de homologação. O console efetivo recebeu a revisão `e2274d8` e o repositório DevOps recebeu `9afe154`. A validação local do console ficou em **35 arquivos / 263 testes aprovados**, `npm run typecheck` aprovado e `npm run build` aprovado. UnifiedUI também passou `npm run build`; Oracle proxy passou `mvn test`; plugin Oracle passou `go test ./...`.

As correções entregues nesta rodada incluem: autorização de usuário-alvo por tenant no provisionamento/grant/offboarding; restrição de role ao catálogo do site; critérios de sucesso alinhados ao componente real do IdP; proprietário/tenant nas sessões RustGuac e autorização seletiva para encerrar/listar/reproduzir; replay de checkout sem reentrega do segredo; descoberta OIDC por metadata; fallback mock somente para sessão explicitamente mock; contrato correto do rollout; restauração que falha quando `pg_restore` falha; imagem Oracle compilada com `-Pojdbc` e renderer sem fallback que duplica statements.

### Matriz de configurabilidade pelo ArchGate Manager

“Configurável por tela” foi avaliado como capacidade de criar/editar/aplicar, acompanhar estado, tratar erro e recuperar a operação sem editar arquivo ou executar script. A equivalência com AWS Console é, portanto, aplicável ao plano de controle diário, não ao bootstrap inicial da infraestrutura.

| Domínio | Cobertura observada nas telas/rotas | Resultado para homologação |
|---|---|---|
| Identidades, grupos e permissões | CRUD, associação, importação, credenciais e recycle bin no console | **Sim**, condicionado ao isolamento multi-tenant corrigido nesta rodada |
| Tenants, sites, targets e roles | cadastro de site, YAML/inventário, targets e aplicação de gateway | **Parcial**: parâmetros avançados e reconciliação ainda precisam de aceite E2E |
| Connectors | enrollment, status, heartbeat, inventário, histórico e rollout | **Parcial**: bootstrap do host, attach do router mTLS e distribuição inicial continuam DevOps; stage/apply teve contrato corrigido |
| Warpgate/Guacamole/RustGuac | targets, sessões, encerramento e gravações via APIs do console | **Parcial**: escopo de gravação/sessão foi fechado no código; gateway real, recording e expiração ainda exigem UAT |
| OpenBao/secrets | health, referências, leases e operações básicas | **Parcial**: unseal/root inicial, engines e disaster recovery continuam bootstrap/ops; não há console para todo o ciclo de infraestrutura |
| Oracle | tela e APIs de operação existentes | **Não liberado como caminho real** até autenticação, lease/cleanup, rotação e E2E Oracle; build/duplicação foram corrigidos |
| UnifiedUI/OIDC | SPA própria com login, catálogo e túnel | **Parcial**: OIDC agora consome discovery e não mascara 401/403; logout BFF e UAT real ainda pendentes |
| Orquestração/Axis | ações de ciclo de vida e sincronização expostas no Manager | **Parcial**: precisa provar efeito real, estado durável e retry; mock/dry-run não pode ser apresentado como concluído |
| DNS, certificados, backup/restore e HA | scripts/runbooks e diagnósticos, sem ciclo completo no Manager | **Não**: permanecem operações de infraestrutura, com restore corrigido para não mascarar erro |

Conclusão: o produto já tem um control plane configurável para o fluxo diário de identidades, sites, targets, conectores e acessos, mas ainda não atende à promessa “qualquer serviço configurável pela tela” em sentido amplo. Para a homologação, a definição recomendada é: bootstrap/recuperação de infraestrutura podem ser operacionais; tudo que um operador administra diariamente após o bootstrap deve ser feito pelo Manager, auditado e tenant-scoped. Oracle, HA, DNS/certificados, disaster recovery e configuração inicial de mTLS devem ficar fora da candidata ou ser concluídos antes do UAT.
