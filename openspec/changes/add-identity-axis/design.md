# Design — Add Identity Axis (Fase 1)

## Contexto

Esta é a fase fundadora da plataforma de acesso privilegiado. Ela estabelece a camada de identidade sobre a qual todas as demais dependem. As decisões aqui condicionam gateways (Fase 1), credenciais efêmeras (Fase 2), rede (Fase 3), UnifiedUI (Fase 4) e o caso agêntico (Fase 5).

## Decisões técnicas

### D1 — ArchGuard (Kanidm) como IdP OIDC — produto existente
Kanidm (Rust, MPL-2.0) é o engine de identidade, **operado pelo produto ArchGuard** (repo IntegrAllTech `archguard`: `kanidmd` + `archguard-console` + AliasVault + `scripts/setup-kanidm.sh`). Motivos: menor footprint, seguro por padrão, e — decisivo — a IntegrAllTech **já tem** o ArchGuard; a Fase 1 do ArchGate **integra** esse produto, não sobe um segundo Kanidm nem reescreve o console. Toda a stack de gateways fala OIDC, então o suporte SAML limitado do Kanidm não é impeditivo. Ver `deploy/archguard-integration.md`.

### D2 — Authorization Code + PKCE, sem fluxos implícitos
Todos os clients OIDC (`warpgate`, `guacamole`, `archguard-console`) usam Authorization Code com PKCE. Fluxos implícitos ficam desabilitados. Isso alinha ao padrão do ArchGuard e evita exposição de token no browser.

### D3 — Tokens sensíveis nunca no browser (padrão ArchGuard)
O console mantém sessão dupla: OIDC para o operador + service account para a API administrativa. Tokens administrativos permanecem server-side; o browser fala apenas com o proxy do próprio console, que valida path e autentica. É o mesmo princípio "o segredo não chega ao cliente" que sustenta toda a plataforma — reaproveitado, não reinventado.

### D4 — Tenancy modelada na identidade
Cada cliente = um tenant, refletido em grupos/escopos no Kanidm. O claim de tenant/grupo viaja no token e é a base para o RBAC dos gateways e do console. O Mentors Axis é a fonte de verdade dos tenants; nesta fase a sincronização pode ser manual/semi-automática, com a automação plena na Fase 4.

### D5 — Service accounts desde a Fase 1
Mesmo sem uso agêntico agora, o primitivo de service account é criado e exercitado. Isso evita retrabalho na Fase 5 e valida o modelo de identidade não-humana cedo.

### D6 — Persistência externa obrigatória
Warpgate default usa SQLite; para HA e auditoria confiável, aponta-se para PostgreSQL externo. Guacamole idem. Sem isso, gravações e RBAC ficam frágeis.

## Estado interino desta fase (honestidade de escopo)

Nesta fase, **o Warpgate detém as credenciais dos alvos** (o dev nunca as vê). A propriedade de *certificado efêmero assinado por CA* (que remove a credencial de longa vida até do gateway) só chega na Fase 2 com o OpenBao.

Consequência importante: o **núcleo da dor de offboarding já é resolvido aqui**. Como o dev nunca possuiu a credencial do alvo, sair da empresa não exige rotacionar senha de cliente — desabilitar a identidade no Kanidm derruba o SSO e o acesso acaba. A Fase 2 adiciona defesa em profundidade (blast radius menor se o próprio gateway for comprometido), não o ganho de negócio principal.

## Riscos e mitigações

- **Claims de tenant/grupo inconsistentes** → validar mapeamento token → RBAC em 2.7 e 6.2 antes de avançar.
- **Persistência frágil (SQLite)** → PostgreSQL externo obrigatório (D6, tarefa 1.1/3.1/4.1).
- **Dependência circular de segredos** → bootstrap fora da plataforma (tarefa 1.3).
- **Suposição de que offboarding só funciona na Fase 2** → explicitar (nesta design) que já funciona na Fase 1 para acesso mediado por gateway.

## Fora de escopo (fases seguintes)
- OpenBao / SSH CA / DB dinâmico → Fase 2.
- NetBird / alcançabilidade de rede → Fase 3.
- UnifiedUI React com `guacamole-common-js` → Fase 4 (nesta fase, UI stock do Guacamole com rebrand leve).
- OpenSRE / fluxo agêntico com HITL → Fase 5.
