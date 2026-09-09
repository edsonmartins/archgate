# Backlog executável para entrada em homologação — 09/09/2026

Status: **em implementação; contenções locais não encerram o gate de homologação**. Progresso e evidências: [primeiro pacote](2026-09-09-primeiro-pacote.md).

Objetivo: produzir uma candidata instalável, administrável pelo Manager e tecnicamente validada para iniciar UAT humano. Este documento não declara o produto homologado nem autoriza implantação, saneamento de dados ou mudanças no ambiente de clientes.

## 1. Base, progresso e limites

Fontes locais utilizadas:

- [Auditoria A01–A20 e atualizações](2026-09-07-prontidao-homologacao.md).
- [Reativação e limitações atuais](2026-09-09-reativacao.md).
- [Plano MVP](../PLAN-HOMOLOGACAO-MVP.md), [plano de produto](../PLAN-PRODUTO-100.md) e [UAT atual](../runbooks/HOMOLOGACAO-UAT.md).
- `archgate-devops/docs/CONSOLE-NORTH-STAR.md`: operação diária pelo Manager; scripts para bootstrap e contingência.

Revisões locais de referência: console `0bce5eb`, ArchGate `30024e0`, DevOps `9afe154`. Relatórios complementares têm alterações locais não necessariamente incluídas nesses commits. Não há confirmação de que essas revisões estejam implantadas.

Já existem correções locais de autorização, replay/persistência de novos segredos, encerramento RustGuac, bloqueio/reativação de login, status de offboarding, contratos de rollout, SQL Oracle e propagação de erro de restore. **Preservar essas correções; implementar o residual e acrescentar evidência.** Testes locais de componentes não equivalem ao aceite das frentes abaixo.

Os antigos `done`, percentuais e PASS de laboratório não encerram este backlog. Alguns documentos descrevem escopos e datas anteriores. Os critérios aqui são propostas de aceite da próxima candidata; ajustes de escopo devem ficar registrados antes do congelamento.

## 2. Decisões de escopo — H00

Responsáveis sugeridos: produto/revisor do piloto e arquitetura. Não são designações já acordadas.

| Decisão | Proposta para a primeira candidata | Consequência |
|---|---|---|
| Protocolos e rede | SSH + Postgres via Warpgate, com pelo menos um site real autorizado | Mantém o núcleo do plano MVP; laboratório sozinho não encerra o gate |
| Console administrativo | Manager obrigatório para tarefas diárias de todos os módulos incluídos | H15 é obrigatório; defeitos de autorização continuam bloqueantes mesmo em telas auxiliares |
| Gateway browser | Escolher um gateway e declarar se browser integra a candidata | Se incluído, H05/H09/H11/H17 devem cobrir esse gateway; não misturar evidência Guacamole/RustGuac |
| UnifiedUI e Connect | Listar clientes e sistemas operacionais realmente incluídos | Cada cliente incluído deve funcionar após login, expiração, offboarding e reativação |
| Oracle | Proposta: fora da primeira candidata, salvo necessidade do piloto | Se incluído, H16 é obrigatório; corrigir driver/SQL não basta |
| Axis/orquestração | Incluir somente as ações anunciadas na experiência do piloto | Ações de sincronização expostas exigem H10; se excluídas, retirar sua disponibilidade efetiva |
| HA/agêntico/protocolos futuros | Proposta: fora da primeira candidata | Uma instância pode ser aceita somente com restrição operacional explícita, backup e restore comprovados |
| Bootstrap e contingência | Instalação inicial de agente, infraestrutura e recuperação física podem seguir runbook | Rotação, grants, revogação e diagnóstico diário não devem exigir SSH ou UI stock |
| Tempos e retenção | Definir prazo de revogação/expiração, RPO, RTO e retenção | Necessário para critérios mensuráveis; não há SLA novo implicitamente aprovado neste documento |

**Saída de H00:** manifesto de escopo com módulos, clientes, protocolos, site piloto, gateway browser, topologia, limites operacionais e responsáveis pelo aceite. Registrar exclusões na UI, documentação e configuração do servidor. Esconder botão não elimina endpoint vulnerável.

## 3. Regras comuns de conclusão

Uma tarefa só pode ser encerrada quando tiver:

1. Alteração revisável nos repositórios envolvidos, com compatibilidade/migração documentada quando necessária.
2. Testes positivos, negativos e de falha pertinentes ao risco.
3. Evidência da candidata identificada por commits e, após empacotamento, digests.
4. Comportamento observável no Manager quando se tratar de operação diária.
5. Nenhum segredo nos logs, respostas indevidas, screenshots ou anexos de evidência.

Estados propostos: `detalhado`, `em implementação`, `implementado localmente`, `validado integrado`, `pronto para UAT`. A existência de testes unitários aprovados só sustenta os estados locais.

## 4. Segurança e identidade

### H01 — Identidade estável e persistência compartilhada — P0, residual

- **Origem:** A01/A03/A08; bloqueio atual por username e diferenças entre e-mail, nome e subject.
- **Entrega:** contrato único de identidade, preferencialmente issuer + subject verificados, com mapeamento servidor para o identificador do IdP e usernames dos gateways. Definir política para usuários multi-tenant e renomeações. Migrar referências de sessões, checkouts, grants e revogações sem atribuir propriedade por aproximação.
- **Persistência:** escolher banco compartilhado para réplicas ou restringir a candidata a uma instância documentada. Registro sem proprietário verificável fica inacessível ao usuário comum e com tratamento administrativo explícito.
- **Aceite:** username diferente de subject e e-mail não impede revogação; usuário renomeado continua bloqueado; identidades homônimas de emissores diferentes não colidem; revogação persiste após reinício. Uma identidade multi-tenant não pode ser globalmente desativada por um administrador com autoridade apenas sobre parte dela.
- **Testes:** matriz de identidades, migração de registros legados, restart e topologia escolhida. Sem reativar bloqueios durante migração.
- **Dependência / responsável:** H00; console + identidade + persistência.

### H02 — Autorizações residuais de pessoas, grupos e targets — P0, parcial

- **Origem:** A01; guards já adicionados, mas ainda falta provar a fronteira completa.
- **Entrega:** revisar handlers e proxy de identidade, criação/provisionamento de pessoa sem tenant, grupos delegáveis, roles e efeito de alterações sobre usuários compartilhados. Operações globais devem exigir autoridade global. Validar também chamadas diretas à API.
- **Aceite:** tenant admin A não concede grupo de plataforma, role B, modifica pessoa B ou bloqueia globalmente usuário compartilhado sem autorização. Usuário sem tenant não fica disponível para apropriação arbitrária por outro tenant. Requisição negada não chama IdP/gateway.
- **Testes:** administrador global, tenant admin A/B, operador, viewer, pessoa sem tenant, pessoa privilegiada e multi-tenant; IDs conhecidos e grupos qualificados/normalizados.
- **Dependência / responsável:** H01; console + identidade.

### H03 — Auditoria e gravações isoladas — P0, parcial

- **Origem:** A02; timeline ainda consulta log global com permissões amplas.
- **Entrega:** atribuir tenant/principal/recurso aos eventos; exigir permissão de auditoria e aplicar escopo no servidor. Revisar listagem, reprodução, exportação e alteração de retenção/legal hold. Separar proprietário da gravação do auditor autorizado do tenant.
- **Aceite:** A não lista, baixa ou altera eventos/gravações B por nenhum endpoint. Gravações encerradas continuam acessíveis a quem tem direito; não depender de a sessão estar aberta. Registros legados sem vínculo ficam restritos e sinalizados.
- **Testes:** paginação, sessão encerrada, ID conhecido, exportação, retenção, ausência de tenant e falha da origem WG.
- **Dependência / responsável:** H01/H02; console + auditoria.

### H04 — Higiene do broker corporativo e dados antigos — P0, residual

- **Origem:** A05; novas respostas já são sanitizadas, mas persistências anteriores não foram saneadas.
- **Entrega:** verificar replay legado antes de retornar conteúdo; negar segredo mesmo em registros criados antes da correção. Inspecionar metadados de retenção e preparar procedimento revisável de saneamento de SQLite/WAL/backups afetados, com política de preservação de evidência. Rever escopo de checkout por conta, organização e principal.
- **Aceite:** chave antiga não reentrega segredo; checkin/expiração impedem nova revelação; credencial sintética não aparece em registros novos. Relatório de exposição histórica indica sistemas afetados e necessidade de rotação, sem reproduzir o segredo.
- **Testes:** base sintética pré-migração, resposta legado com `secret`, TTL vencido, checkin, retry e concorrência. A limpeza de dados reais é uma operação separada, com alvos e impacto explícitos.
- **Dependência / responsável:** H01/H02; console + segurança/DevOps.

## 5. Ciclo de acesso

### H05 — Offboarding completo e retomável — P0, parcial

- **Origem:** A03/A06; há bloqueio local e cleanup RustGuac, mas não revogação integral comprovada.
- **Entrega:** persistir operação e etapas por principal; impedir novas admissões antes de enumerar sessões; encerrar cada gateway incluído; fechar checkouts da identidade correta; integrar H06/H08; repetir apenas o necessário após falha. Distinguir bloqueio de login, encerramento de sessão e revogação de autorização.
- **Aceite:** após revogar A, novas conexões são negadas e as existentes terminam no prazo definido em H00; B continua operando. Falha externa mantém estado parcial e permite retry pelo Manager. Restart entre etapas não perde a operação nem declara sucesso.
- **Testes:** SSH/PG ativos, RustGuac se incluído, sessão emitida durante offboarding, serviços indisponíveis, processo encerrado após cada etapa, revogação repetida e duas solicitações concorrentes.
- **Dependência / responsável:** H01/H02/H06/H08; console + gateways + orquestração.

### H06 — Inventário de leases e ACL mínima — P0, contenção aplicada

- **Origem:** A04; prefixo global removido, adaptador retorna parcial por falta de inventário.
- **Entrega:** vincular lease exato a principal, tenant, target, sessão/operação e expiração no momento da emissão. Compensar emissão se a criação da sessão falhar. Reconciliar leases pendentes/órfãos; revogar somente IDs comprovadamente pertencentes ao escopo. Substituir ACLs wildcard por capacidades e caminhos necessários.
- **Aceite:** revogar A não revoga lease B mesmo compartilhando role DB. Falha ao criar sessão não deixa credencial utilizável além do prazo acordado. Lease sem proprietário verificável não é atribuído a A apenas pelo prefixo.
- **Testes:** dois usuários na mesma role, permissão insuficiente, OpenBao indisponível, perda de resposta, restart entre emissão e persistência, lease já expirado e target fora do escopo.
- **Dependência / responsável:** H01; console/broker + OpenBao + orquestração.

### H07 — TTL efetivo das concessões — P1, aberto

- **Origem:** A07.
- **Entrega:** grant durável com identidade, tenant, target, origem e `expires_at`; worker/reconciliação de expiração; aplicar negação no caminho de acesso real. Modelar concessões sobrepostas para que expirar um grant não remova outro válido.
- **Aceite:** grant curto deixa de admitir conexões automaticamente no prazo definido; restart/worker indisponível não tornam a concessão permanente. Uma role compartilhada não dá acesso a targets adicionais sem autorização. Definir em H00 se sessão já ativa é encerrada na expiração ou por limite próprio.
- **Testes:** relógio controlado, expiração E2E SSH/PG, duas concessões sobrepostas, worker parado/reiniciado, renovação e expiração concorrentes. Não basta testar que o TTL aparece no log.
- **Dependência / responsável:** H01/H06/H08; console + gateways + worker.

### H08 — OpenFGA consistente e revogação completa — P1, aberto

- **Origem:** A08.
- **Entrega:** alinhar subject de grant/check/revoke; migrar tuplas existentes; ler todas as páginas e remover em lotes suportados; limitar exclusão às relações da operação. Definir comportamento em indisponibilidade e quais caminhos consultam autorização.
- **Aceite:** nome diferente do subject funciona; todas as páginas de grants A são removidas sem tocar B; erro de leitura/exclusão resulta em parcial/negação, nunca autorização implícita. Se OpenFGA ficar fora do escopo, documentar e testar o mecanismo de autorização substituto.
- **Testes:** múltiplas páginas, retomada, duplicidade, falha no segundo lote, tuplas legadas e cada protocolo incluído.
- **Dependência / responsável:** H00/H01; autorização + console.

### H09 — Login, logout, MFA e reativação completos — P1, parcial

- **Origem:** A10 e relatório de reativação; dimensão de segurança bloqueante quando permite acesso indevido.
- **Entrega:** provar `auth_time` do IdP e nova autenticação; completar bearer Connect para usuário reativado ou excluí-lo explicitamente; serializar offboarding/reativação; manter corte temporal em todos os caminhos. Logout deve invalidar sessão servidor. Conferir issuer, audience, assinatura, state/nonce/PKCE e rejeição de tokens inválidos em cada cliente incluído. Definir e validar MFA/step-up das ações privilegiadas do piloto.
- **Aceite:** login → sessão → offboarding → reativação → novo login funciona; cookies/tokens anteriores permanecem negados; refresh antigo não ressuscita acesso. Falha IdP mantém bloqueio. Duas ações concorrentes têm resultado determinístico e auditado.
- **Testes:** browser real, bearer/desktop se incluído, ausência de auth_time, fronteira de segundo, token com assinatura/audience incorretas, logout e replay, expiração, nova revogação durante reativação.
- **Dependência / responsável:** H01/H05; identidade + console + clientes.

### H10 — Orquestração e sincronização reais — P1, condicionada às ações incluídas

- **Origem:** A06/A16.
- **Entrega:** operações duráveis e idempotentes; sync Axis efetivo quando anunciado; resultados explícitos para executado, parcial, indisponível e simulado. Reconciliar efeitos reais dos adapters e evitar duplicações em retry.
- **Aceite:** mesmo pedido repetido não duplica concessão; restart preserva andamento; configuração mock/desabilitada não é apresentada como execução real. Uma falha de adapter é visível no Manager.
- **Testes:** APIs integradas de teste, interrupção entre adapters, perda de resposta, retry, falha parcial e comparação entre estado desejado e efetivo.
- **Dependência / responsável:** H01/H05/H06/H08; orquestração + console + Axis.

## 6. Conectividade, operação e release

### H11 — Connector seguro e rollout recuperável — P1, segurança bloqueante se exposto

- **Origem:** A12/A13; contrato artifact_url/url já corrigido.
- **Entrega:** roteamento mTLS completo e derivação de identidade do certificado; sobrescrever headers vindos do cliente e impedir bypass público. Vincular serial ao connector/site/tenant; unificar consulta à fonte de sites; rotação e revogação pela tela. Persistir etapa de upgrade e recuperação.
- **Aceite:** certificado errado/revogado e headers forjados são negados; rotação não afeta outro connector. Stage/apply/rollback em agente real funcionam; falha de hash, download ou processo não deixa status “aplicado” falso.
- **Testes:** endpoint público e interno, matrícula reutilizada/expirada, serial de B solicitado por A, perda de rede, restart, rollback e site piloto real.
- **Dependência / responsável:** H01/H02; console + agente/DevOps.

### H12 — Auditoria entregue e falhas observáveis — P1 se exportação incluída

- **Origem:** A15.
- **Entrega:** recuperar outbox abandonada em `publishing`, retry periódico com limites e deduplicação no destino. Mostrar idade da fila, falhas e tentativa manual autorizada. Para escopo sem exportação, demonstrar integridade e retenção da auditoria local e deixar exportação indisponível.
- **Aceite:** processo morre após claim, reinicia e evento é entregue sem duplicação lógica; destino indisponível não perde evento e produz alerta. Nenhuma operação parcial importante é silenciosa.
- **Testes:** crash, timeout, resposta perdida, indisponibilidade prolongada e retorno do destino.
- **Dependência / responsável:** H03; console + observabilidade/DevOps.

### H13 — Backup e restore comprovados — P1, parcial

- **Origem:** A14; erro do pg_restore já é propagado.
- **Entrega:** inventariar PG, SQLite/WAL, OpenBao, configurações e gravações dos gateways incluídos. Restaurar em destino único e isolado; validar integridade, contagens e operação restaurada; documentar RPO/RTO e proteção dos backups. Exibir estado/última execução no Manager.
- **Aceite:** dump inválido falha; restore válido recupera dados e permite o fluxo de teste; mede perda máxima e tempo de recuperação. Não usar o banco compartilhado do piloto como destino de teste.
- **Testes:** backup ausente/corrompido, recuperação de gravação, bloqueio persistido após restore e dependências necessárias para subir a aplicação.
- **Dependência / responsável:** H00/H01/H04; DevOps + persistência.

### H14 — Candidata reproduzível e dependências — P1, parcial

- **Origem:** A09/A17/A18.
- **Entrega:** fixar Node/npm/JDK/Go/Rust necessários; validar lockfile em checkout limpo e geração de rotas antes de typecheck. Executar CI nos commits finais, revisar imports server-side no build cliente, licença e vulnerabilidades aplicáveis a runtime/build. Empacotar por digest e preparar rollback. Para desktop incluído: instalador assinado/notarizado conforme plataforma e instalação limpa.
- **Aceite:** instalação/checks/build reproduzíveis no ambiente de CI escolhido; alertas aplicáveis resolvidos ou avaliação explícita aceita, sem ignorar severidade automaticamente. Artefato instalado corresponde à revisão testada.
- **Testes:** checkout limpo, instalação limpa do cliente, configuração de homologação sem entradas lab/mock indevidas, inspeção de bundle e varredura de imagens/dependências.
- **Dependência / responsável:** H00 e alterações do escopo estabilizadas; mantenedores + CI/DevOps.

### H15 — Aceite de operação pelo Manager — P1, transversal e obrigatório

- **Origem:** solicitação de console administrativo completo; não equivale a paridade de funcionalidades com a AWS.
- **Entrega:** inventário de operações administrativas por serviço incluído: tela, endpoint, permissão, estado persistido, diagnóstico, retry e auditoria. Corrigir o que exigir SSH/UI stock no dia a dia. Padronizar estados solicitado/em execução/concluído/parcial/falhou, com resultados reais.
- **Aceite:** administrador executa os fluxos abaixo pelo Manager e entende a falha sem procurar logs por SSH. A UI respeita RBAC, mas o servidor continua sendo a autoridade. Operações destrutivas têm confirmação e alvo explícito.
- **Testes:** navegador, tenant A/B e viewer, refresh durante operação, erro de integração, timeout e retry. Registrar passos, resultado e capturas sanitizadas; não apenas screenshots do formulário.
- **Dependência / responsável:** cada H correspondente; frontend + backend + QA.

| Jornada de aceite H15 | Etapas exigidas | Tarefas |
|---|---|---|
| Novo cliente | Tenant/site → connector → target → usuário → teste → estado aplicado | H01/H02/H10/H11 |
| Conceder acesso | Escolher pessoa/target → prazo → aplicar → consultar → expirar/revogar | H06/H07/H08 |
| Desligar e reativar | Confirmar alvo → acompanhar etapas → retry → reativar → novo login | H05/H09 |
| Administrar sessões/auditoria | Listar → filtrar → encerrar → consultar evento/gravação autorizada | H03/H05/H12 |
| Manter connector | Diagnosticar → rotacionar certificado/segredo → atualizar → rollback | H11 |
| Operar plataforma | Saúde → falha acionável → status de backup/restore e fila de auditoria | H12/H13 |

### H16 — Oracle real — P1 condicional

- **Origem:** A11; driver e preservação de comandos já corrigidos.
- **Entrega:** autenticação obrigatória do proxy, emissão via lease com expiração/cleanup, rotação efetiva da credencial administrativa e injeção no gateway sem revelar senha de alvo ao operador.
- **Aceite:** conectar em Oracle descartável com credencial emitida, expirar/revogar e provar que a credencial deixa de funcionar; rotação não interrompe emissões futuras; acesso não autenticado ao proxy é recusado.
- **Testes:** criação multi-statement, falha parcial, timeout, rollback/cleanup, revogação e rotação reais. A tela deve cobrir as operações incluídas.
- **Dependência / responsável:** H00/H06/H09/H15; Oracle + OpenBao + console.

## 7. Evidência integrada e entrada em UAT

### H17 — Pré-UAT técnico da candidata — P1

- **Entrega:** atualizar roteiro antigo com endpoints/IdP/gateway atuais; preparar identidades de teste, dois tenants, alvos e site real autorizado; executar jornadas completas na candidata empacotada. Acrescentar matriz adversarial e de falhas ao roteiro de caminho feliz.
- **Cenários obrigatórios:** login/logout; SSH e PG; isolamento A/B; grant/TTL; sessão ativa durante offboarding; falha/retry; reativação e token antigo; auditoria; restore. Browser, Connect e Oracle entram conforme H00.
- **Evidência por cenário:** ID, pré-condições, persona, alvo, revisão/digest, horário, ação, resultado esperado/observado, anexo sanitizado, PASS/FAIL e bug associado. SKIP não satisfaz requisito obrigatório.
- **Aceite:** todas as jornadas obrigatórias passam; nenhum P0 aberto; P1 do escopo encerrados; instalação/rollback documentados. Não é necessário esperar assinatura de UAT para começar UAT.
- **Dependência / responsável:** H01–H16 aplicáveis + H14; QA + operação do piloto.

### H18 — Pacote e execução da homologação humana

- **Entrega:** candidata congelada, escopo/exclusões, instruções de acesso, roteiro, limitações conhecidas, evidências técnicas e responsáveis. Registrar aceite ou rejeição do revisor e defeitos encontrados.
- **Entrada:** H17 aprovado e ambiente disponível. **Saída:** decisão humana registrada; eventual ressalva não pode ocultar falha de isolamento ou credencial exposta.
- **Responsável sugerido:** revisor de negócio/técnico e produto. Data deve ser combinada após estimar capacidade e disponibilidade do site; não reutilizar automaticamente a data de julho.

## 8. Sequenciamento para implementação

| Lote | Entrega revisável | Pré-requisito | O que pode andar em paralelo |
|---|---|---|---|
| 0 | H00 e contratos de H01 | Revisão deste detalhamento | Inventário H04/H13 e diagnóstico CI H14 |
| 1 | H01/H02/H03/H04: fronteiras de identidade e dados | Contratos de identidade/escopo | Frentes de auditoria e broker após acordo de schema |
| 2 | H06/H08, depois H05/H07/H09 | Identidade e autorização definidas | Integrações de leases e OpenFGA; testes de IdP |
| 3 | H10/H11/H12/H13 e cobertura H15 | Escopo; contratos dos lotes anteriores | Conectividade, observabilidade e restore isolado |
| 4 | H16 se incluído; H14 final; H17 | Caminhos contratados implementados | Empacotamento e preparação de dados de UAT |
| 5 | H18 | Pré-UAT aprovado | Acompanhamento de bugs do revisor |

H15 é um critério de cada lote, não uma fase final de “embelezamento”. H14 começa cedo para detectar problemas de ambiente, mas sua evidência final deve corresponder aos commits congelados.

Primeiro pacote proposto para implementação: **H01 contrato/migração + H02 autorização residual + H03 restrição da timeline**. Antes de ampliar funcionalidades, fechar a exposição entre tenants e estabilizar a identidade usada no restante do ciclo. H04 (replay legado) pode ser corrigido em paralelo após delimitar o escopo do broker. Não iniciar saneamento real de dados só por concluir o código.

## 9. Dependências externas e estimativas

Dependências a confirmar durante a preparação: IdP de teste e claims reais; conta técnica de menor privilégio; site/peer e janela autorizada do piloto; gateway/protocolos escolhidos; destino isolado de restore; certificados de assinatura caso desktop incluído; disponibilidade do revisor.

Não há estimativa de prazo confiável nesta etapa. H01/H05/H06/H07/H09 concentram incerteza de arquitetura e integração. Para estimar, primeiro validar contratos dos serviços, fixar escopo e dividir cada entrega em mudanças revisáveis; depois separar esforço de engenharia de espera por ambiente/cliente. Nenhum percentual de conclusão é derivado da quantidade de testes ou de tickets.

## 10. Portões de liberação

**Pronto para implementar:** escopo proposto revisado, contratos das primeiras tarefas definidos e cenários de aceite entendidos. Este documento é o detalhamento dessa preparação.

**Pronto para entrar em homologação:** H17 aprovado, zero P0 aberto, P1 aplicáveis concluídos, candidata reproduzível, fluxos administrativos contratados no Manager e site real preparado. Funcionalidade excluída deve estar efetivamente indisponível quando sua exposição trouxer risco.

**Homologado:** H18 executado com decisão humana registrada. Produção, expansão para múltiplos clientes e paridade administrativa ampla permanecem marcos distintos.
