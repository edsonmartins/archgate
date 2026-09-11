# Reativação de login — 09/09/2026

Implementada ação “Reativar login” no detalhe da identidade, restrita a system:admin, com confirmação pelo username. O servidor exige auth_time no login verificado do administrador, bloqueio local existente, ausência de sessões broker pendentes e sucesso do IdP. A ação é auditada. A reativação grava um corte temporal persistente: cookies sem auth_time ou com autenticação anterior/no mesmo segundo continuam negados, inclusive após reinício. O refresh da sessão antiga também é recusado.

Validação local: typecheck aprovado; suíte existente com 272 testes aprovada; cinco testes adicionais do handler aprovados (permissão, auth_time ausente, cleanup pendente, falha IdP e sucesso auditado); build aprovado. O teste de persistência verifica cookies antigos, ausência de data, novo login e novo bloqueio. Não houve teste de navegação em navegador nem E2E com IdP real.

Limitações para homologação:

- É necessário confirmar que o IdP real emite auth_time no ID token e permite forçar nova autenticação. Sem esse claim, a operação fica indisponível.
- O bearer atual usa userinfo e não comprova auth_time; permanece negado para usuários reativados. A tela informa a limitação do Connect.
- O corte depende de username consistente e banco SQLite compartilhado pelos processos. Identidade canônica e múltiplas réplicas continuam pendentes.
- Ainda é preciso serializar operações concorrentes de reativação/offboarding e testar emissão concorrente nos demais gateways.
- Reativar login não comprova remoção de todos os grants antigos; concessões precisam ser revisadas. A conclusão do inventário de leases e reconciliação permanece bloqueante.

Esta entrega disponibiliza o controle no código, mas não libera o gate de homologação nem representa implantação em produção.
