# INICIAR_ARCHGATE.md — Prompt de início

> Cole este conteúdo como primeira mensagem no Claude Code, com este pacote na raiz do repositório. Ele conduz o arranque da Fase 1.

---

Você vai implementar o **ArchGate**, a plataforma de acesso privilegiado (bastion/gateway) da IntegrAllTech, de forma **spec-driven**. O objetivo do produto: desenvolvedores acessam infraestruturas de clientes **sem jamais ver a credencial do alvo**, com offboarding central e tudo auditado.

## Leia primeiro (nesta ordem)

1. `CONSTITUTION.md` — invariantes de projeto (precede tudo; nunca viole).
2. `PROMPT_EXECUCAO_CLAUDE_CODE.md` — regras de trabalho e guardrails.
3. `PLATAFORMA_ACESSO_PRIVILEGIADO.md` — arquitetura completa.
4. `openspec/project.md` — stack, estrutura de repo e convenções.
5. `openspec/changes/README.md` — ordem das fases.
6. `openspec/changes/add-identity-axis/` — o pacote da Fase 1 (proposal → design → specs → tasks).

## Passo 0 — Intake de ambiente (antes de qualquer código)

Confirme comigo as decisões `[A DEFINIR]` de `openspec/project.md`, pois o restante depende delas:

1. **Estrutura de repositório** — monorepo (sugerido) ou polyrepo?
2. **Alvo de deploy, DNS e TLS** — onde roda o Swarm; quais domínios para archguard/Warpgate/Guacamole; TLS via Traefik/Let's Encrypt?
3. **Segredos de bootstrap** — onde ficam raiz/unseal do OpenBao e admin, fora da própria plataforma?
4. **Alvos de teste** — host SSH, host Windows (RDP) e PostgreSQL de teste para validar a Fase 1.
5. **Pinning de versões** — fixar versões de archguard/OpenBao/Warpgate/Guacamole/NetBird.

Não avance sem essas respostas. Se eu não as tiver agora, proponha padrões razoáveis e peça confirmação.

## Passo 1 — Confirmar entendimento

Depois do intake, resuma em poucas linhas: (a) o escopo da Fase 1, (b) os invariantes inegociáveis da CONSTITUTION que você vai respeitar, e (c) o critério de "pronto" da fase (gates). Aguarde meu OK.

## Passo 2 — Executar a Fase 1

Comece pela tarefa **1.1** de `add-identity-axis/tasks.md`, **uma tarefa por vez**. Para cada tarefa:
- implemente conforme design/specs;
- valide o cenário WHEN/THEN correspondente;
- marque `- [x]` no `tasks.md` **só após validar**;
- relate o que foi feito e o que foi validado.

## Regras que não mudam

- **Zero-credencial-no-dev.** Se uma tarefa parecer exigir expor segredo ao dev, **pare e sinalize** — está errada.
- **Ordem das fases.** Não antecipe escopo de fases futuras (na Fase 1, frontend é a UI stock do Guacamole com rebrand leve; a UnifiedUI React é Fase 4).
- **Decisões em aberto.** Ao esbarrar num ponto que dependa de ADR não resolvido, **pare e escreva o ADR** pedindo confirmação — não adivinhe.
- **Specs e código em sincronia.** Para divergir de uma spec, altere a spec primeiro.

## Definition of done da Fase 1

Todas as tarefas `[x]` e validadas; todos os cenários passando; **teste de offboarding** (desabilitar identidade no archguard derruba o SSO nos gateways); **nenhuma credencial de alvo exposta ao dev**; sessões gravadas e reproduzíveis.

---

**Comece agora pelo Passo 0.**
