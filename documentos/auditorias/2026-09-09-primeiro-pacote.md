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

Sem implantação e sem alterações no ambiente de clientes.
