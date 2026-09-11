# Design — Add Agentic Access & HA (Fase 5)

## Contexto
Última fase: operar em produção com HA e permitir acesso agêntico governável. O princípio que rege tudo aqui: **o agente é não-confiável por padrão**, e a segurança mora no gateway, não no bom senso do modelo.

## Decisões técnicas

### D1 — Agente é apenas mais um principal
O bastion é agnóstico a quem está do outro lado. O OpenSRE é uma **service account** no archguard com escopo mínimo. Toda a maquinaria de identidade/credencial efêmera/gravação já se aplica sem alteração estrutural.

### D2 — Política no gateway, nunca no modelo
Um agente SRE lê logs/alertas — conteúdo **não-confiável**, superfície de prompt injection. Portanto não se confia no julgamento do agente: allow-list de comandos, escopo por host, TTL curtíssimo e rate limit são **impostos no Warpgate/OpenBao**. Uma linha de log maliciosa não pode escalar privilégio.

### D3 — HITL obrigatório para write
Leitura ampla pode ser automática; qualquer ação mutante/destrutiva passa por aprovação humana roteada em tempo real (base: fluxo de aprovação web do Warpgate). Read-only primeiro; relaxar só com histórico comprovado.

### D4 — On-behalf-of e kill-switch
Cada ação do agente é amarrada à service account **e** ao humano que autorizou (cadeia de responsabilização). Se o agente descarrilar, revoga-se a service account no archguard → próximo cert não sai → expira em minutos. É o mesmo mecanismo do offboarding humano, reaproveitado como kill-switch.

### D5 — Inferência local por LGPD
Agente operando em produção de cliente e tocando dado pessoal exige que a inferência rode **localmente** (vLLM na RTX 3060 / Mac Mini M4), sem enviar dado de produção a APIs de terceiros. Local-first deixa de ser economia e vira requisito de conformidade.

### D6 — HA proporcional ao risco
OpenBao (centro de gravidade) em HA com auto-unseal seguro; archguard replicado; persistência externa; gateways stateless. Failover testado por componente.

## Riscos e mitigações
- **Prompt injection** → política no gateway (D2) + teste explícito (6.4).
- **Blast radius** → TTL curtíssimo, escopo por incidente, rate limit (3.x).
- **Perda de responsabilização** → on-behalf-of obrigatório (D4).
- **Vazamento de dado a LLM de terceiro** → inferência local (D5).
- **Agente alpha em produção de cliente** → read-only primeiro, HITL, consentimento (postura faseada).

## Nota
OpenSRE é alpha; colocar agente autônomo com acesso privilegiado a produção de cliente é barra alta. O caminho é read-only → write com HITL, relaxando gates apenas quando a gravação e o histórico provarem comportamento.
