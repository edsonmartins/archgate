# Como contribuir com o ArchGate

Contribuições são bem-vindas: correções, testes, documentação, specs, novos protocolos e integrações. O ArchGate é uma plataforma de acesso privilegiado, então segurança vem antes de tudo: leia este guia e o [`CONSTITUTION.md`](CONSTITUTION.md) antes de abrir o PR.

## Antes de começar

- Para correções pequenas (bug, teste, documentação), abra o PR direto.
- Para mudanças de comportamento, abra antes uma [issue](https://github.com/edsonmartins/archgate/issues) descrevendo a proposta. O projeto é **spec-driven**: mudança de comportamento começa por um change OpenSpec (veja abaixo), e decisão de arquitetura começa por um ADR.
- **Falhas de segurança não vão em issue pública.** Use [Report a vulnerability](https://github.com/edsonmartins/archgate/security/advisories/new) na aba Security do repositório.

## Invariantes

O [`CONSTITUTION.md`](CONSTITUTION.md) tem precedência sobre qualquer PR. Um PR que viole um invariante não entra, mesmo que funcione. Os principais:

- **Zero-credencial-no-dev:** a credencial do alvo nunca chega ao principal (humano ou agente). O gateway injeta.
- **Política na infraestrutura:** autorização é imposta por ArchGuard, gateways e OpenBao, nunca pelo cliente.
- **Efemeridade:** nada de credencial de longa vida.
- **Licenças:** nada de copyleft forte nem licenças source-available no núcleo (detalhes no §4 do `CONSTITUTION.md`). O CI barra isso com `scripts/license-gate.sh`.

## Fluxo spec-driven (OpenSpec)

Changes vivem em [`openspec/changes/`](openspec/changes/), cada um com `proposal.md`, `design.md`, `tasks.md` e `specs/<capability>/spec.md`. As convenções estão em [`openspec/project.md`](openspec/project.md).

1. Leia proposal → design → specs → tasks do change em que vai trabalhar.
2. Implemente **uma** tarefa por vez e marque `[x]` só depois que o cenário WHEN/THEN correspondente passar de fato.
3. Se a implementação precisar divergir da spec, altere a spec primeiro, no mesmo PR.
4. Esbarrou numa decisão de arquitetura? Escreva um ADR em [`adr/`](adr/) e discuta no PR antes de seguir.

## Preparando o ambiente

1. Faça um fork do repositório e clone o seu fork.
2. Instale o que for usar, conforme a parte do monorepo que vai mexer:

| Parte | Caminho | Requisito |
|---|---|---|
| Serviços Java | `services/orchestration`, `services/agent-control`, `services/oracle-proxy` | Java 21 + Maven |
| Plugin Oracle do OpenBao | `services/openbao-oracle-plugin` | Go |
| ArchGate Connect (CLI + desktop) | `clients/archgate-connect` | Go (e Rust/Tauri para o desktop) |
| UnifiedUI | `frontend/unified-ui` | Node 22 |
| Scripts de deploy/validação | `deploy/`, `clients/` | bash + shellcheck |

3. Crie uma branch a partir da `main`:

```bash
git switch -c fix/descricao-curta
```

O deploy oficial vive no repositório `archgate-devops`; o diretório `deploy/` daqui é histórico e serve de referência.

## Antes de abrir o PR

Rode o que o CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) roda, na parte que você alterou:

```bash
# Serviços Java (em cada services/<servico>)
mvn -B test

# Go (em clients/archgate-connect e services/openbao-oracle-plugin)
go build ./... && go vet ./... && go test ./...

# UnifiedUI (em frontend/unified-ui)
npm ci && npx tsc --noEmit && npx vite build

# Scripts (na raiz)
find deploy clients -name '*.sh' -type f -print0 | xargs -0 shellcheck --severity=error

# Licenças (na raiz)
bash scripts/license-gate.sh
```

Inclua testes para o que mudou. Correção de bug vem com um teste que falhava antes e passa depois.

### Segredos e dados de cliente

Nunca commite `bootstrap.env`, chaves age, tokens, certificados, gravações de sessão, logs de auditoria ou dados de clientes (IPs, hostnames, inventários reais). Use os templates (`*.template.yaml`, `*.example.*`) e valores fictícios nos testes e na documentação.

## Commits

Seguimos [Conventional Commits](https://www.conventionalcommits.org/):

```
fix(connect): reconnect keeps the embedded session alive
feat(openbao): dynamic credentials for the Oracle proxy
docs(adr): ADR-015 — gravação de sessões no gateway
```

Tipos usados: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`. O escopo entre parênteses é o componente (`connect`, `orchestration`, `oracle-proxy`, `openbao`, `deploy`, `ui`, `adr`, `openspec`...). Quando o commit implementa uma tarefa de um change, referencie-o no corpo (ex.: `add-ephemeral-credentials #2.5`).

Documentação e specs em **pt-BR**; código e identificadores em **inglês**.

No corpo do commit, explique o porquê: o que estava errado e o que a mudança resolve. O diff já mostra o como.

### Assinatura (DCO)

Todo commit de contribuição precisa da linha `Signed-off-by`, que declara que você tem o direito de enviar aquele código sob a licença do projeto, nos termos do [Developer Certificate of Origin](https://developercertificate.org/). Basta commitar com `-s`:

```bash
git commit -s -m "fix(connect): session list survives token refresh"
```

Esqueceu em commits já feitos? Assine todos de uma vez e atualize o PR:

```bash
git rebase --signoff main
git push --force-with-lease
```

Um check chamado **DCO** confere a assinatura em cada PR.

## O PR

- Um assunto por PR. Correções independentes vão em PRs separados.
- Descreva o problema, a solução e como você testou (qual cenário WHEN/THEN passou). O modelo de PR já traz essas seções.
- Mudança visual na UnifiedUI ou no desktop: inclua print ou gif.
- Mudança em fluxo de credencial, identidade ou gateway recebe revisão mais rigorosa: explique no PR por que o invariante zero-credencial-no-dev continua valendo.

No seu primeiro PR, o CI só roda depois que um mantenedor aprovar a execução. É uma proteção padrão do GitHub para contas novas no repositório; a partir do segundo PR ele roda sozinho.

O merge acontece depois do CI verde e da revisão de um mantenedor.

## Licença

O ArchGate é distribuído sob a [Apache License 2.0](LICENSE). Ao contribuir, você concorda que sua contribuição seja licenciada nos mesmos termos. Componentes de terceiros (ArchGuard/Casdoor, Warpgate, Guacamole, OpenBao) mantêm suas respectivas licenças.
