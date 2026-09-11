# CONSTITUTION.md — ArchGate

> Invariantes de projeto. Este documento tem precedência sobre qualquer pacote de mudança, tarefa ou implementação. Uma mudança que viole um invariante aqui **não é executada** — a divergência exige emenda formal desta constituição (ver §8), não um contorno em código.

## §1 — Identidade do produto

ArchGate é a **plataforma de acesso privilegiado** (bastion/gateway) da IntegrAllTech. Seu propósito é permitir que desenvolvedores — e, no futuro, agentes — acessem infraestruturas de clientes **sem jamais possuir a credencial do alvo**, com offboarding em um ponto único e tudo auditado. O **ArchGuard** é o módulo de identidade dentro do ArchGate ("o Guard controla quem passa pelo Gate").

## §2 — Invariantes de segurança (inegociáveis)

1. **Zero-credencial-no-dev.** A credencial do alvo nunca chega ao principal. O gateway injeta; o principal apenas usa. Qualquer fluxo que exponha o segredo ao dev é inválido por construção.
2. **Política no gateway, nunca no principal.** Autorização e limites são impostos pela infraestrutura (Warpgate/OpenBao/archguard). Nunca se confia no julgamento do usuário ou de um agente.
3. **Efemeridade por padrão** (a partir da Fase 2). Credenciais de curta duração. Nada de longa vida na mão de ninguém — nem do gateway.
4. **Identidade é o alicerce.** Todo acesso deriva de identidade autenticada no archguard. Revogar identidade = revogar acesso.
5. **Tudo auditável e reversível.** Toda sessão gravada; toda concessão rastreável a um principal e a uma autorização; kill-switch central.

## §3 — Invariantes de soberania (LGPD)

1. **Self-hosted.** Gravações, logs de auditoria e segredos residem na infraestrutura da IntegrAllTech, em território nacional.
2. **Inferência local para dado de cliente.** Quando um agente operar sobre dado de produção de cliente, a inferência roda localmente (vLLM na infraestrutura própria). Dado de produção de cliente **não** trafega para APIs de terceiros.
3. **Consentimento.** Operação (humana ou agêntica) em ambiente de cliente pressupõe acordo do cliente.

## §4 — Invariantes de arquitetura

1. **Composição, não produto único.** Os engines (archguard, OpenBao, Warpgate, Guacamole, NetBird) são operados e integrados, não reescritos.
2. **Preferência por governança de fundação** nas peças críticas (Apache, Linux Foundation). Evitar licenças copyleft forte (AGPL) e source-available (BSL/FSL) no núcleo.
3. **Persistência externa.** Warpgate e Guacamole usam PostgreSQL externo — nunca SQLite em produção.
4. **OIDC Authorization Code + PKCE.** Fluxos implícitos desabilitados.
5. **Tokens sensíveis fora do browser.** Padrão de proxy server-side com validação de path (herança do ArchGuard).
6. **Sem credencial de longa vida no gateway** após a Fase 2.

## §5 — Invariantes de metodologia

1. **Spec-driven.** Nada se implementa sem spec. A ordem é sempre proposal → design → specs → tasks.
2. **Cenários são o critério de aceite.** Uma tarefa só está pronta quando o cenário WHEN/THEN correspondente passa de fato.
3. **Specs e código em sincronia.** Se a implementação exigir divergir da spec, altera-se a spec primeiro. Código não diverge silenciosamente.
4. **Decisões em ADR.** Ao esbarrar num ponto de decisão, escreve-se um ADR e aguarda-se confirmação. Não se adivinha.
5. **Gates de fase.** Uma fase só fecha com todas as tarefas validadas, todos os cenários passando, teste de offboarding OK e nenhuma credencial exposta ao dev.

## §6 — Ordem das fases (dependência)

1. `add-identity-axis` — identidade.
2. `add-ephemeral-credentials` — OpenBao (SSH CA + DB dinâmico).
3. `add-oracle-credential-proxy` — proxy Java Oracle (pré-requisito Oracle da Fase 3).
4. `add-network-mesh` — NetBird + cobertura de protocolo.
5. `add-unified-ui-and-orchestration` — UnifiedUI + orquestração Mentors Axis.
6. `add-agentic-access` — HA + agêntico.

Não se antecipa escopo de fase futura. Não se inicia fase sem a anterior concluída e validada.

## §7 — O que nunca acontece

- Expor credencial de alvo ao dev.
- Deixar credencial de longa vida no gateway após a Fase 2.
- Enviar dado de produção de cliente a LLM de terceiro.
- Dar a um agente confiança por padrão (read-only primeiro; HITL para write; kill-switch validado).
- Confiar em julgamento de principal para decisão de política.
- Usar SQLite para Warpgate/Guacamole em produção.
- Implementar acesso Oracle sem o mecanismo do ADR-001.

## §8 — Emenda

Este documento muda apenas por decisão explícita registrada como ADR, revisada e aceita. Nenhum pacote de mudança, tarefa ou pressão de prazo altera um invariante sem emenda. Em caso de conflito entre esta constituição e qualquer outro artefato, esta constituição prevalece.
