# Prompt de Execução — Plataforma de Acesso Privilegiado (Claude Code)

> **Como usar:** cole este conteúdo como instrução inicial no Claude Code, ou salve como `CLAUDE.md` na raiz do repositório para que valha como contexto persistente. Ele governa a implementação dos pacotes OpenSpec em `openspec/changes/`.

---

## Seu papel

Você vai implementar, de forma **spec-driven**, a plataforma de acesso privilegiado (bastion/gateway) da IntegrAllTech. O objetivo do produto: desenvolvedores (e, no futuro, agentes) acessam máquinas, bancos, Kubernetes e painéis dos clientes **sem jamais ver ou possuir a credencial do alvo**, com offboarding em um clique e tudo auditado.

Você **não improvisa arquitetura**. As decisões já estão tomadas nos artefatos. Seu trabalho é executá-las com fidelidade, tarefa a tarefa, validando cada cenário.

## Fontes de verdade (leia antes de codar)

1. `PLATAFORMA_ACESSO_PRIVILEGIADO.md` — documento de arquitetura (contexto, componentes, decisões, ADRs em aberto).
2. `openspec/changes/README.md` — índice das fases, ordem de dependência e evolução das capabilities.
3. Para cada fase, o pacote em `openspec/changes/<change>/`: leia **nesta ordem** `proposal.md` → `design.md` → os `specs/<capability>/spec.md` → `tasks.md`.

Se houver ferramenta `openspec` no repositório, use-a para validar/inspecionar as mudanças. Mantenha specs e código em sincronia: se a implementação exigir divergir da spec, **pare e proponha a alteração da spec primeiro**, não faça o código divergir silenciosamente.

## Princípios inegociáveis (guardrails — nunca viole)

1. **Zero-credencial-no-dev.** A credencial do alvo nunca chega ao principal. O gateway injeta; o dev apenas usa. Se uma tarefa parecer exigir expor segredo ao dev, está errada — pare e sinalize.
2. **Política no gateway, não no principal.** Autorização e limites são impostos por Warpgate/OpenBao/Kanidm, nunca delegados ao julgamento do usuário ou de um agente.
3. **Efemeridade por padrão** (a partir da Fase 2). Credenciais de curta duração; nada permanente na mão de ninguém — nem do gateway.
4. **Tudo auditável e reversível.** Toda sessão gravada; toda concessão rastreável a uma identidade; revogação central.
5. **Soberania / LGPD.** Gravações, logs e (Fase 5) inferência de IA rodam self-hosted. Dado de produção de cliente **não** sai para APIs de terceiros.
6. **Identidade é o alicerce.** Todo acesso deriva de identidade autenticada no Kanidm. Revogar identidade = revogar acesso.

## Ordem de execução (respeite as dependências)

1. `add-identity-axis` (Fase 1) — identidade + gateways confiando no Kanidm + console.
2. `add-ephemeral-credentials` (Fase 2) — OpenBao (SSH CA + DB dinâmico).
3. `add-network-mesh` (Fase 3) — NetBird + cobertura de protocolo. **Bloqueada pelo ADR-001 (Oracle).**
4. `add-unified-ui-and-orchestration` (Fase 4) — React/`guacamole-common-js` + orquestração Mentors Axis.
5. `add-agentic-access` (Fase 5) — HA + OpenSRE governável.

Não comece uma fase sem a anterior concluída e validada. Não antecipe escopo de fases futuras (ex.: não construa a UnifiedUI React na Fase 1 — nela o frontend é a UI stock do Guacamole com rebrand leve).

## Fluxo por pacote de mudança

Para cada `<change>`:
1. Leia proposal → design → specs → tasks.
2. Implemente **uma tarefa por vez**, na ordem do `tasks.md`.
3. Os **cenários WHEN/THEN** das specs são os critérios de aceite. Uma tarefa só está pronta quando o cenário correspondente passa de fato.
4. Marque `- [x]` no `tasks.md` **apenas** após implementar E validar. Não marque por antecipação.
5. Ao concluir o pacote, rode a seção de validação de ponta a ponta antes de declarar a fase pronta.

## Convenções de stack (IntegrAllTech)

- **Backend:** Spring Boot 3.x + Java 21 + PostgreSQL. **Frontend:** React 18/19 + TypeScript + Mantine v9 (Archbase quando aplicável).
- **Deploy:** Docker Swarm + Traefik (roteamento/TLS de borda).
- **Componentes de terceiros (não reescreva; opere e integre):** Kanidm (identidade), OpenBao (segredos efêmeros), Warpgate (SSH/HTTPS/K8s/MySQL/PostgreSQL), Apache Guacamole + guacd (RDP/VNC/browser), NetBird (malha WireGuard).
- **Console/identidade:** ArchGuard (interno) sobre Kanidm — reaproveite o padrão de token fora do browser (proxy server-side com validação de path).
- **Persistência:** Warpgate e Guacamole em **PostgreSQL externo** — nunca o SQLite default do Warpgate em produção.
- **Autenticação:** OIDC Authorization Code + PKCE; fluxos implícitos desabilitados.

## Gates de fase (definition of done)

Uma fase só fecha quando, cumulativamente:
- Todas as tarefas do `tasks.md` estão `[x]` e validadas.
- Todos os cenários das specs da fase passam.
- **Teste de offboarding** passa: desabilitar a identidade no Kanidm derruba o acesso; da Fase 2 em diante, credenciais ativas expiram sozinhas; **nenhuma senha de cliente é rotacionada**.
- **Nenhum fluxo expõe credencial de alvo ao dev.**
- Sessões gravadas e reproduzíveis.

## O que NÃO fazer

- Não pular decisões em aberto. Ao esbarrar num ponto que depende de ADR, **pare e sinalize** — não adivinhe. Em especial: **ADR-001 (Oracle) bloqueia a Fase 3**; não implemente acesso Oracle sem essa decisão fechada.
- Não colapsar a fronteira **ArchGuard × Mentors Axis** antes do **ADR-004**. Se a orquestração exigir definir quem faz o quê, sinalize.
- Não deixar credencial de longa vida no gateway após a Fase 2.
- Não enviar dado de produção de cliente a LLMs de terceiros (Fase 5: inferência local).
- Não dar a um agente (Fase 5) confiança por padrão: read-only primeiro, HITL para write, kill-switch validado.
- Não sobre-engenheirar além da fase atual.

## Decisões em aberto (ADRs — ver §16 do doc de arquitetura)

ADR-001 (Oracle via OpenBao — **bloqueador Fase 3**), ADR-002 (step-ca), ADR-003 (persistência Warpgate), ADR-004 (fronteira ArchGuard × Mentors Axis — **antes da Fase 4**), ADR-005 (nome), ADR-006 (estratégia de frontend). Quando uma decisão for necessária, escreva um ADR curto (contexto, opções, recomendação) e peça confirmação antes de prosseguir.

## Como reportar progresso

A cada bloco de trabalho: atualize os checkboxes do `tasks.md`, descreva o que foi validado e como, e liste bloqueios. Se propuser mudança de spec ou um novo ADR, apresente em Markdown e aguarde confirmação.

---

## Primeiro comando

1. Leia `PLATAFORMA_ACESSO_PRIVILEGIADO.md` e `openspec/changes/README.md`.
2. Leia o pacote `add-identity-axis` completo.
3. Resuma em poucas linhas seu entendimento do escopo da Fase 1 e confirme os princípios inegociáveis.
4. Comece pela tarefa **1.1** do `add-identity-axis/tasks.md`, uma tarefa por vez, validando cada cenário.
