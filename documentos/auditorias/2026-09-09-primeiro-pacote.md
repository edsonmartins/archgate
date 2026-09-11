# Primeiro pacote de correções — 09/09/2026

Referência: [backlog H00–H18](2026-09-09-backlog-executavel-homologacao.md). Esta rodada implementa contenções de H02/H03/H04 e define o contrato inicial de H01. Não encerra essas frentes nem libera homologação.

## Alterações implementadas

- H02: operações de lifecycle que usam `assertPrincipalTenantAccess` exigem que todos os tenants da pessoa estejam dentro do escopo do administrador. Pessoas com grupos administrativos de plataforma são recusadas. Pessoas sem tenant comprovado exigem administração de plataforma; removida a exceção de primeiro provisionamento por tenant admin, pois ausência de grupos não comprova propriedade.
- H03: os dois handlers de auditoria global exigem `system:admin` antes de consultar SQLite ou Warpgate. A tela informa restrição/indisponibilidade em vez de apresentar erro de autorização como lista vazia. Auditoria delegada por tenant permanece indisponível até existir vínculo confiável nos eventos.
- H04: replay de checkout não usa mais a resposta original como fallback. Registro legado sem metadados seguros de replay recebe 409; campo `secret` na resposta de replay também é recusado. Respostas seguras de aprovação pendente continuam disponíveis. Nenhum banco, WAL ou backup real foi saneado nesta rodada.

Validação: typecheck e suíte de 288 testes aprovados após H02/H03; mais três testes específicos de checkout legado aprovados após H04; build aprovado. Testes verificam negação antes da leitura externa, pessoa multi-tenant, privilegiada, sem tenant, estrangeira, lookup indisponível e resposta com segredo legado. Não houve teste de navegação autenticada nem E2E no piloto.

## H01 — contrato proposto para a migração

Evidência de código: `archguard-console/src/server/archguard-session-context.ts` já resolve `subject` pela orquestração e retorna `identity_id`, `identity_status` e memberships. Atualmente valida correspondência de subject e status, mas a migração ainda precisa validar schema, issuer configurado, identificador e memberships ativas em todos os caminhos de autenticação.

| Dado | Origem autorizada | Uso |
|---|---|---|
| issuer + subject | Token validado por issuer, audience e assinatura; configuração de provedor aprovada | Chave de autenticação externa; nunca username/e-mail como substituto silencioso |
| identity_id | Contexto de identidade validado pelo servidor, vinculado ao issuer autorizado | Chave interna de grants, leases, sessões, revogações e checkouts |
| organization_id e membership_id | Membership ativa retornada pela autoridade de identidade | Escopo organizacional; mapear explicitamente para tenant/site |
| Username por gateway | Associação explícita, validada pela autoridade do adapter | Identificador operacional para chamadas WG/IdP; não chave universal de autorização |
| E-mail e nome | Perfil | Exibição/auditoria; alteração não troca proprietário dos acessos |
| auth_time | Claim verificado do IdP | Corte temporal após reativação; ausência não deve ser preenchida com hora do cliente |

Regras de migração propostas:

1. Validar contrato de contexto em cookie e bearer e recusar contexto divergente/inativo antes de emitir sessão. Manter identidade externa associada ao provedor, inclusive se hoje houver um único issuer.
2. Adicionar referências internas sem remover campos legados; preencher vínculos somente quando comprovados pela autoridade de identidade. Não inferir usuário ou tenant pelo e-mail, prefixo de role ou nome parecido.
3. Inventariar sessões/grants/checkouts/revogações sem vínculo; mantê-los restritos e em fila administrativa. Bloqueio legado não pode desaparecer por falta de correspondência na migração.
4. Converter leituras, escritas, claims de operação e critérios de autorização como uma versão de schema explícita. Uma dupla escrita temporária não autoriza usar a chave antiga como fallback permissivo.
5. Testar alteração de username/e-mail, dois issuers com subjects iguais, memberships revogadas, pessoa multi-tenant, restart e rollback. Rollback deve preservar os bloqueios produzidos na versão nova.
6. Escolher persistência compartilhada para réplicas ou impor instância única documentada na candidata. A topologia ainda não está encerrada por este contrato.

O contrato acima está documentado; a migração de dados e o uso generalizado de identity_id **não foram implementados** nesta rodada.

## Pendências do primeiro pacote

### Incremento H01 — validação do contexto (2026-09-09)

Integrado no console local no commit `f082b33`: o resolvedor de contexto rejeita JSON inválido, identificadores ausentes/vazios/com espaços externos e estruturas de memberships malformadas. Mantém as verificações de subject e identidade ativa e disponibiliza apenas memberships com status `active`. Subject inválido é recusado antes da chamada externa.

Validação local: 302 testes passaram em 40 arquivos, incluindo 13 testes do contexto; `tsc --noEmit` passou. Não houve deploy nem validação integrada do provedor real. Isso não integra o resolvedor ao login por cookie nem conclui a migração de identity_id/issuer, a persistência compartilhada ou o isolamento do proxy genérico (H02).

- H01: executar a migração e integrar a identidade interna a todos os consumidores, com validação do contrato real.
- H02: revisar o proxy genérico de identidade e demais handlers; a proteção do lifecycle não cobre automaticamente APIs independentes. Prover fluxo de onboarding tenant-scoped com propriedade comprovada para pessoas novas.
- H03: gravar tenant/principal em eventos, implementar consultas e exportações delegadas e validar retenção/gravações encerradas. A restrição global é contenção, não a entrega completa de auditoria por tenant.
- H04: revisar autorização por conta/organização, classificar registros/backups históricos e preparar saneamento/rotação com alvos explícitos.
- Confirmar escopo H00 e executar evidências integradas do piloto antes do gate.

## Incremento H02 — contenção do proxy global

O proxy genérico de identidade agora exige `system:admin`, além das verificações existentes, para todas as operações exceto `GET /status` exato. A credencial usada pelo proxy é global e o transporte não comprova propriedade dos recursos por tenant; permissões de operação não são suficientes para delegar esse acesso. A restrição abrange leitura de coleções, pessoas, grupos, credenciais, OAuth, contas de serviço, configuração e recuperação de objetos.

Impacto funcional explícito: operações delegadas que usam esse proxy passam a receber erro de autorização. Não foram implementados endpoints tenant-scoped substitutos nem validada a experiência de erro de todas as telas. A administração delegada completa (H02/H15) permanece pendente; administrador de plataforma mantém acesso. A exceção de saúde continua exigindo sessão e permissão de leitura correspondente.

Validação local: 319 testes em 41 arquivos e `tsc --noEmit` passaram, incluindo 17 testes novos do handler com chamadas upstream simuladas. Os testes verificam negação antes do acesso externo, saúde somente no caminho exato e manutenção da allowlist para administrador. Não houve teste E2E nem build nesta rodada.

## Incremento H02/H15 — recuperação de credenciais e erros de consulta

Console local `3d24d0a`: `personApi.createResetToken` usa um endpoint dedicado, com sessão e `persons:credentials` (ou administração de plataforma), validação de ID/TTL e limite de requisições. Resolve UUID/nome via API de identidade, confere correspondência com o ID solicitado e aplica `assertPrincipalTenantAccess` ao username antes de emitir o token. A pessoa deve ter todos os tenants dentro do escopo do operador e não pode ser privilegiada ou sem tenant; administrador de plataforma conserva autoridade global. O token não é persistido na auditoria, e corpos de erro HTTP do IdP não são devolvidos pelo endpoint.

Listagem e detalhe de pessoas agora apresentam alerta e nova tentativa quando a consulta falha, explicitando a restrição de administração global. Não confundir essa correção com uma listagem tenant-scoped: essa consulta continua pendente, portanto o endpoint dedicado ainda não entrega a jornada completa de um administrador delegado pela tela.

Validação: 334 testes em 42 arquivos, TypeScript e build passaram; 15 testes novos cobrem autorização, escopo, associação ID/username, entrada inválida e higiene da auditoria/erro HTTP. Sem teste de navegador ou IdP real. Ainda é preciso provar os contratos das duas interfaces de identidade usadas (consulta v1 e grupos via adapter), tratar alteração concorrente de memberships e concluir a identidade canônica H01. A checagem seguida da emissão externa não constitui operação atômica distribuída. Nenhuma dessas frentes foi encerrada.

## Incremento H01/H02 — vínculo da evidência de grupos à identidade

Console local `6e04966`: a consulta `getUser` exige sucesso HTTP, nome exatamente igual ao solicitado e owner igual à organização configurada. Grupos malformados são recusados. A consulta de grupos não transforma prefixos de organizações estrangeiras ou caminhos de múltiplos segmentos em autoridade local. Essa validação precede o uso dos grupos pelos guards e protege também consumidores de `getUser`, como desativação/reativação.

Validação: 344 testes em 42 arquivos e TypeScript passaram. Dez testes novos verificam identidade/organização divergente, grupos inválidos/estrangeiros, falha HTTP e ausência de escrita ao receber outro usuário. Não houve build nem integração real nesta rodada. A listagem por tenant continua não implementada: esta correção fecha uma pré-condição de confiança necessária para usá-la. Não resolve a migração de issuer/identity_id nem concorrência entre leitura de grupos e mutação.

## Incremento H02/H15 — consulta de pessoas por tenant

Console local `def32c0`: listagem e detalhe usam endpoints dedicados, com sessão e `persons:read`, projeção explícita de atributos e validação de ID/nome. Para não administradores de plataforma, grupos são consultados pelo adapter de identidade; somente pessoas não privilegiadas com todos os tenants no escopo do operador são retornadas. Pessoas compartilhadas fora desse escopo e sem tenant são excluídas. O filtro do navegador não é a fronteira de autorização. Falha na verificação de grupos aborta a consulta; não é convertida em lista vazia bem-sucedida. Detalhe de pessoa fora do escopo é recusado mesmo com ID conhecido.

A API upstream utilizada continua sem paginação: o endpoint aceita até 1.000 registros, rejeita inventários maiores/ambíguos/malformados e limita a oito consultas de grupos simultâneas. Isso limita concorrência, não o tempo total da operação; paginação real, carga e deadlines globais permanecem pendentes. A consulta global ainda ocorre internamente; apenas dados filtrados e projetados são devolvidos ao navegador.

Validação local: 356 testes em 43 arquivos e TypeScript passaram; build terminou com sucesso, mas emitiu avisos de módulos Node externalizados para browser via better-sqlite3, mantendo a revisão de bundle H14 pendente. Doze testes novos cobrem isolamento, acesso direto ao detalhe, associação divergente, falha de grupos, atributos desconhecidos e inventário inválido/duplicado/excessivo. Não houve navegação autenticada ou validação do contrato com IdP real.

Este incremento substitui a pendência de implementação da listagem/detalhe registrada nas rodadas anteriores, mas não seu aceite integrado. Credenciais/MFA, grupos, edição, criação e exclusão que ainda usam o proxy global continuam restritos. A jornada delegada completa, concorrência de memberships e H01 seguem abertos.

## Incremento H07 — inventário de grants na ficha da pessoa

Console local `cb0061e`: a ficha de identidade agora consulta, com autorização tenant-scoped, os grants TTL emitidos pelo console e exibe target, role, vencimento e estado (ativo, expirado ou revogado). A tela mantém a revogação integral separada e informa que a revogação individual nativa ainda depende do vínculo seguro com OpenFGA e Warpgate.

Validação local: 379 testes em 49 arquivos, TypeScript e build passaram. A consulta não expõe grants de pessoas fora do escopo do operador. Ainda faltam revogação individual real nos adapters, identidade canônica por `identity_id`, paginação do inventário e validação E2E com integrações reais.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H05 — etapas de offboarding persistidas

Console local `f5d7b6c`: cada etapa do offboarding agora é persistida com sequência, componente, resultado e detalhe limitado. A operação mantém `operation_id` e estado final `completed` ou `partial`, permitindo identificar o ponto de falha após erro externo ou restart.

Validação local: 384 testes em 51 arquivos e TypeScript passaram. Ainda falta expor o histórico de etapas na tela e implementar retomada automática a partir da primeira etapa incompleta; a validação com integrações reais permanece pendente.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H05 — lock e retomada de offboarding

Console local `273e34d`: cada offboarding agora cria uma operação persistida por principal, impede duas revogações concorrentes e devolve `operation_id`. Execuções que permanecem em `running` por mais de 15 minutos são marcadas como parciais e permitem nova tentativa. O resultado final registra `completed` ou `partial` sem alterar a ordem das etapas externas.

Validação local: 384 testes em 51 arquivos e TypeScript passaram, incluindo concorrência e retomada após operação stale. Ainda falta persistir cada etapa individual, recuperar automaticamente uma operação interrompida no meio sem nova solicitação e validar gateway/orquestração reais.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H12/H15 — retry manual da outbox pelo Manager

Console local `e2ebcbe`: o painel Plataforma oferece retry manual da outbox somente para sessões com `settings:update` ou `system:admin`. O destino e o token permanecem exclusivamente no servidor; a operação retorna a contagem publicada e atualiza o diagnóstico da fila. Sem destino configurado, a ação falha explicitamente.

Validação local: 383 testes em 50 arquivos, TypeScript e build passaram. Ainda faltam destino externo real, alertas/métricas, confirmação de idempotência no receptor e teste E2E com operador autenticado.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H12/H15 — saúde da fila de auditoria no Manager

Console local `97ae8a3`: o painel Plataforma passa a exibir contagem de eventos pendentes, em publicação, falhos e publicados, além do evento mais antigo pendente. O endpoint retorna apenas metadados operacionais; payloads e mensagens brutas de erro não são expostos ao navegador.

Validação local: 383 testes em 50 arquivos, TypeScript e build passaram. Ainda faltam destino externo real, métricas/alertas, confirmação de idempotência no receptor e validação E2E da operação pelo Manager.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H07/H08 — revogação individual fail-closed para grants legados

Console local `5840979`: quando OpenFGA está ativo, um grant legado sem subject/objeto exatos não pode ser marcado como revogado apenas no SQLite. A operação individual retorna erro orientando o offboarding completo, que remove os subjects conhecidos. A resposta também sinaliza quando a role Warpgate compartilhada permanece, evitando declarar revogação total.

Validação local: TypeScript e 10 testes focados de grants/OpenFGA passaram. A revogação nativa de roles compartilhadas continua deliberadamente fora da ação individual até existir modelagem por target sem risco de remover acesso legítimo.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H07/H08 — revogação individual da tupla exata

Console local `1d6b8c3`: grants novos passam a persistir subject e objeto OpenFGA. A ficha da pessoa oferece revogação individual; o servidor valida o proprietário e remove somente a tupla exata antes de marcar o grant local como revogado. Tuplas inseguras ou relações diferentes de `connect` são rejeitadas.

Validação local: TypeScript e 7 testes específicos de OpenFGA passaram; a suíte anterior de 382 testes permaneceu verde antes deste teste adicional. A associação nativa de role no Warpgate ainda não é revogada por esta operação, e a migração de grants/tuplas legados permanece pendente.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H07 — grants sobrepostos preservam concessão válida

Console local `566eb5f`: a decisão de acesso deixou de considerar apenas o grant mais recente. Quando existem concessões sobrepostas para o mesmo principal e target, o BFF permite a conexão enquanto houver ao menos uma concessão não revogada e não expirada; a expiração de uma concessão não remove outra válida.

Validação local: 382 testes em 50 arquivos e TypeScript passaram, incluindo relógio controlado para grant expirado sobreposto a grant válido. Ainda faltam migração de tuplas legadas, revogação individual nos adapters e teste E2E real.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H01/H08 — subject OpenFGA alinhado à identidade estável

Console local `028e80d`: grants novos materializam `user:<identity_id>` quando a ficha da pessoa fornece o identificador estável; o BFF consulta o mesmo `identityId` ao verificar `connect`. O offboarding, quando recebe `person_id`, remove tanto o subject canônico quanto o username legado, preservando a compatibilidade da migração.

Validação local: 381 testes em 50 arquivos e TypeScript passaram. Isso corrige novos fluxos, mas não migra automaticamente tuplas antigas nem prova o contrato com OpenFGA real; tuplas legadas, falhas parciais e múltiplos issuers permanecem pendentes.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H06 — compensação de lease em falha de sessão

Console local `391eea2`: quando credenciais dinâmicas são emitidas pelo console e a criação do ticket RustGuac falha, o lease recém-criado é revogado imediatamente. O inventário de leases também recebeu desempate determinístico para não variar quando sessões são registradas no mesmo instante.

Validação local: 381 testes em 50 arquivos e TypeScript passaram. A compensação cobre o erro na criação do ticket, mas ainda exige validação integrada com OpenBao/RustGuac reais e cobertura do caso de falha entre a criação do ticket e o registro final da sessão.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H06 — worker periódico de reconciliação de leases

Console local `221e90a`: a reconciliação de leases expirados pode ser ativada explicitamente com `BROKER_LEASE_RECONCILER_ENABLED=1`. O intervalo é limitado entre 5 segundos e 15 minutos, o timer não mantém o processo vivo no shutdown e cada ciclo atua somente sobre leases registrados pelo próprio console, reportando tentativas fechadas e falhas para retry posterior.

Validação local: 381 testes em 50 arquivos e TypeScript passaram, incluindo os limites de agendamento. A ativação continua deliberadamente explícita para evitar múltiplos workers concorrentes em réplicas; ainda falta configurar o processo singleton da candidata, validar OpenBao/RustGuac reais, métricas/alertas e compensação de emissão de credencial quando a sessão não é criada.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H14 — fronteira de persistência no build cliente

Console local `d26d2a5`: as funções auxiliares exportadas de troca de tokens, montagem de sessão, resolução de roles e concessão foram marcadas com `createServerOnlyFn`. O grafo de importação antes da correção ligava componentes cliente a persistência por `auth.ts` e `lifecycle-fn.ts`; após a correção, a inspeção do grafo não encontrou `better-sqlite3`, `db.ts`, `principal-revocation.ts` ou `audit-outbox.ts` no ambiente cliente. Os avisos de externalização de SQLite desapareceram no build executado. Isso não é evidência de vazamento anterior de dados: a presença no grafo durante transformação e a inclusão efetiva no bundle final são distintas.

Adicionada verificação de build para recusar a presença desses módulos no grafo cliente, sem mascará-los com novos stubs. Validação: 362 testes em 44 arquivos, TypeScript e build passaram; seis novos testes exercitam a barreira. O aviso de chunk grande permanece. Os stubs preexistentes de outros módulos Node/SSR não foram removidos; a barreira não é uma auditoria completa de todos os módulos servidor nem substitui teste autenticado no navegador. H14 permanece parcial.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H07 — TTL de grant efetivo no caminho de conexão

Console local `ce5a144`: grants materializados pela tela agora persistem `principal`, target, role, `created_at`, `expires_at` e `revoked_at` em `access_grants`. O TTL recebe formato explícito (`s`, `m`, `h` ou `d`), com limite de 1 minuto a 24 horas e default de 8 horas; valores inválidos não chegam aos adapters. O BFF consulta o grant mais recente antes de emitir qualquer sessão e recusa grant expirado ou revogado. O offboarding também revoga os registros locais mesmo quando a remoção no OpenFGA falha.

Validação local: 379 testes em 49 arquivos, TypeScript e build passaram. O controle cobre as sessões emitidas pelo console e preserva o caminho legado quando não há registro local para permitir migração gradual. Ainda falta revogar automaticamente a associação nativa de usuário-role no Warpgate no vencimento, usar `identity_id` canônico em vez de principal textual, listar/editar/revogar grants pela tela e validar o TTL em OpenFGA/Warpgate reais. Portanto H07 está parcialmente fechado e não libera homologação isoladamente.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H01/H09 — contexto estável antes da emissão da sessão

Console local `4912f6c`: a sessão criada a partir de tokens agora resolve o `subject` validado no endpoint de contexto do control plane antes de emitir o cookie. O `identity_id` retornado é persistido como `identityId`, junto às memberships ativas; o bearer Connect já usava o resolvedor e passou a persistir o mesmo identificador. A revogação local e a validação de grupos continuam bloqueios anteriores à sessão.

Impacto operacional: login não é concluído quando o contexto de identidade está ausente, divergente, inativo ou malformado. Isso exige configurar o endpoint e token de orquestração na candidata; não há fallback permissivo para username/e-mail. Validação: 377 testes em 48 arquivos, TypeScript e build passaram. Não houve login browser nem IdP/control plane real nesta rodada; issuer/audience/subject de múltiplos provedores, migração dos registros legados e persistência compartilhada continuam pendentes.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H08 — revogação OpenFGA paginada e validada

Console local `bd6ea41`: a remoção de grants agora consulta por `user` + `relation`, segue `continuation_token` com limite e rejeita token repetido. Cada tupla precisa corresponder exatamente ao usuário/relação solicitados e possuir objeto `connection:`; a exclusão ocorre em lotes de 100. O padrão anterior, que usava `object: connection:` como falso curinga e uma única página, foi removido.

Validação local: 377 testes em 48 arquivos e build passaram. Dois cenários novos cobrem 101 grants em múltiplas páginas/lotes, tupla adulterada e paginação circular. A identidade usada pelo caller ainda precisa ser alinhada ao `identity_id` canônico H01; migração de tuplas legadas, grants sobrepostos, falha após lote intermediário e validação OpenFGA real continuam pendentes.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H06 — inventário escopado de leases e expiração

Console local `abce670`: sessões do broker agora persistem `target` e `lease_expires_at`, além de principal, tenant e lease ID. Emissões de credenciais dinâmicas propagam a duração retornada pelo OpenBao; registros de segredo com duração textual também são convertidos com validação. Foram adicionadas consultas de inventário e de leases expirados, sempre limitadas a registros emitidos pelo próprio console.

A reconciliação tenta encerrar somente sessões registradas cujo lease expirou, revogando o ID exato e reportando `attempted/closed/failed`; não atribui nem revoga leases externos por prefixo ou role. Validação: 375 testes em 48 arquivos, TypeScript e build passaram. A reconciliação ainda precisa ser acionada por worker operacional e não prova ACL mínima do OpenBao, inventário de órfãos externos ou expiração efetiva no caminho real de acesso.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H06 — contenção da revogação manual de leases

Console local `94cda3d`: `revokeOpenBaoLeaseFn` deixou de aceitar `secrets:manage` como autorização suficiente. Como a entrada legada recebe apenas um `lease_id`, sem vínculo verificável com principal, tenant, target ou sessão, a operação agora exige `system:admin`; o cleanup de sessão permanece usando o lease exato persistido no registro do broker.

Validação local: 373 testes em 48 arquivos e build passaram. Dois testes novos verificam negação antes da chamada ao OpenBao e sucesso somente para administrador de plataforma. Isso é contenção, não inventário de leases: emissão, owner, expiração, reconciliação de órfãos e ACL mínima continuam pendentes.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H12 — retry periódico da outbox

Console local `2c56f39`: quando `AUDIT_OUTBOX_FORWARDER_URL` está configurada, o processo inicia um ciclo periódico de encaminhamento. O intervalo configurável é limitado entre 5 segundos e 15 minutos, o timer não impede o shutdown (`unref`) e nenhum ciclo é criado sem destino explícito. Claims antigos continuam sendo recuperados antes do lote.

Validação local: 371 testes em 47 arquivos e build passaram. Dois testes novos cobrem ausência de destino, intervalo mínimo e não duplicação do timer. A implementação ainda depende de um único processo por instância: em múltiplas réplicas, cada processo pode encaminhar lotes da mesma base somente se a persistência for compartilhada. Destino real, idempotência confirmada no receptor, alertas e métricas da fila continuam pendentes.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H03/H12 — recuperação de claims da outbox

Console local `4a22f2e`: a outbox passou a persistir `claimed_at`. Claims em `publishing` que excedem o limite de 60 segundos são convertidos em `failed`, recebem nova disponibilidade e podem ser tentados novamente; claims recentes não são apropriados por outro forwarder. Publicação e falha limpam o claim. A recuperação é executada antes de cada lote do forwarder, sem expor corpos de erro ou alterar a deduplicação por `event_id`.

Validação local: 369 testes em 46 arquivos e build passaram. Três testes cobrem queda simulada, claim recente e retomada. Isso reduz o estado preso após crash, mas não conclui o worker periódico: se nenhum novo lote for acionado, não há processo para executar a recuperação. Retry periódico, alertas, métrica da fila, destino real e garantia de entrega idempotente continuam pendentes.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H03 — contexto de principal e tenant nos eventos

Console local `71b2937`: novos eventos de atividade persistem o principal derivado da sessão autenticada e `tenant_ids` derivados dos grupos normalizados da mesma sessão. A lista é gravada no evento e no outbox; não há inferência por e-mail, username ou caminho. Foi adicionada migração compatível para as colunas novas; registros antigos permanecem sem vínculo explícito e seguem sujeitos à consulta global restrita.

Validação local: 367 testes em 46 arquivos e TypeScript passaram. A cobertura existente de persistência/restart continua aprovada. Ainda falta consulta/exportação delegada por tenant, instrumentação dos eventos de todos os gateways, vínculo canônico `identity_id`, reconciliação de registros legados e validação de destino do outbox.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H03 — retenção somente para gravação existente e autorizada

Console local `6444d8c`: a rota de retenção agora consulta o catálogo real do RustGuac antes de persistir qualquer política. Para operadores que não são administradores de plataforma, exige também sessão histórica persistida do próprio principal, incluindo sessões já encerradas. UUID válido, sozinho, não cria nem altera registro de retenção. Falhas de catálogo, gravação inexistente ou proprietário ausente retornam 404 sem escrita; administrador de plataforma mantém a operação global, desde que a gravação exista.

Validação: 367 testes em 46 arquivos e build passaram. Três testes novos cobrem UUID inexistente, ausência de propriedade e operação administrativa validada. Ainda faltam retenção efetiva no storage do RustGuac, tenant persistido no registro/evento, exportação, legal hold real e teste E2E de playback/retention.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H03 — propriedade histórica de gravações encerradas

Console local `ed08e9b`: a autorização da lista de gravações passou a usar um índice histórico de sessões do principal, separado da consulta de sessões abertas usada para cleanup e reativação. Com isso, o fechamento de uma sessão não remove o direito do próprio proprietário de consultar sua gravação. O detalhe de playback já exigia vínculo persistido com o principal e continua retornando 404 para identidade ou sessão fora do escopo; administrador de plataforma mantém o acesso global.

Validação local: 364 testes em 45 arquivos e build passaram. Dois testes novos confirmam que sessões fechadas permanecem no índice histórico, enquanto a lista operacional continua somente com sessões abertas. O aviso de chunk grande permanece. Ainda falta validar gravações reais com RustGuac, tenant persistido no evento, exportação, retenção e registros sem vínculo.

Sem implantação e sem alterações no ambiente de clientes.

## Incremento H05 — histórico de operações de offboarding no Manager

Console local `e90c998`: cada operação de offboarding agora persiste suas etapas com sequência, componente, sucesso/falha, detalhe sanitizado e horário. A tela de detalhe da pessoa consulta as operações recentes do próprio principal e exibe o status da operação e o resultado de cada etapa, incluindo execuções parciais e falhas. O acesso permanece limitado por tenant e pelas permissões `persons:read`, `persons:update` ou `system:admin`.

Validação local: 384 testes em 51 arquivos, TypeScript e build passaram. O histórico torna a execução verificável após a resposta da API e após reinício do processo, mas ainda não implementa retomada automática a partir da primeira etapa incompleta. Persistência compartilhada, integrações reais de OpenFGA/Warpgate/RustGuac/OpenBao, testes E2E e alertas operacionais continuam pendentes para fechar H05 e homologar.

Sem implantação e sem alterações no ambiente de clientes.
