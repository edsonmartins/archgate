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

## Incremento H14 — fronteira de persistência no build cliente

Console local `d26d2a5`: as funções auxiliares exportadas de troca de tokens, montagem de sessão, resolução de roles e concessão foram marcadas com `createServerOnlyFn`. O grafo de importação antes da correção ligava componentes cliente a persistência por `auth.ts` e `lifecycle-fn.ts`; após a correção, a inspeção do grafo não encontrou `better-sqlite3`, `db.ts`, `principal-revocation.ts` ou `audit-outbox.ts` no ambiente cliente. Os avisos de externalização de SQLite desapareceram no build executado. Isso não é evidência de vazamento anterior de dados: a presença no grafo durante transformação e a inclusão efetiva no bundle final são distintas.

Adicionada verificação de build para recusar a presença desses módulos no grafo cliente, sem mascará-los com novos stubs. Validação: 362 testes em 44 arquivos, TypeScript e build passaram; seis novos testes exercitam a barreira. O aviso de chunk grande permanece. Os stubs preexistentes de outros módulos Node/SSR não foram removidos; a barreira não é uma auditoria completa de todos os módulos servidor nem substitui teste autenticado no navegador. H14 permanece parcial.

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
