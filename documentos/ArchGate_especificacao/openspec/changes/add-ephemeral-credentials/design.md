# Design — Add Ephemeral Credentials (Fase 2)

## Contexto
Esta fase remove credenciais de longa vida do caminho de acesso, inclusive do gateway. É a peça que fecha a promessa "menor privilégio + menor duração" de ponta a ponta. Depende da identidade (Fase 1) para amarrar cada emissão a um principal.

## Decisões técnicas

### D1 — SSH via CA, não via chave estática
Os alvos passam a confiar na **chave pública da CA** do OpenBao. O acesso se dá por certificado SSH assinado com TTL curto (5–15 min), contendo o principal e as extensões permitidas. Vantagem sobre distribuir chaves: nada de longa vida no alvo nem no gateway; revogação por não-emissão + expiração.

### D2 — Banco via credencial dinâmica
Acesso a PostgreSQL usa o database secrets engine: usuário criado sob demanda, permissões mínimas, TTL, revogado ao fim do lease. Elimina senha de banco compartilhada.

### D3 — OpenBao é o centro de gravidade
Como o OpenBao emite tudo, ele concentra risco. Mitigações: modo HA, unseal seguro, policies mínimas, auditoria de emissão, e bootstrap guardado **fora** da plataforma (evitar dependência circular).

### D4 — Rastreabilidade principal → credencial
Toda emissão é amarrada à identidade archguard do solicitante. A auditoria precisa responder: quem pediu, para qual alvo, com qual TTL, e quando expirou/foi revogado.

### D5 — Oracle e step-ca ficam para decisão
- **Oracle** (Consinco/Rio Quality) não tem engine dinâmico validado ainda → **ADR-001**, tratado na Fase 3.
- **step-ca** como alternativa/complemento para a CA SSH → **ADR-002**. Nesta fase seguimos com o SSH engine do OpenBao; se o ADR-002 recomendar step-ca, a `ephemeral-credentials` é ajustada.

## Riscos e mitigações
- **Relógio dessincronizado** quebra validação de certificado de TTL curto → NTP nos alvos e gateway.
- **Unseal manual** vira gargalo operacional → avaliar auto-unseal seguro (D2 de operação).
- **Migração incompleta** deixa chave antiga no alvo → checklist 4.2/6.1 exige remoção das credenciais de longa vida.

## Fora de escopo
NetBird (Fase 3), Oracle dinâmico (ADR-001/Fase 3), UnifiedUI (Fase 4), agêntico (Fase 5).
