# Design — Add Unified UI and Orchestration (Fase 4)

## Contexto
Transforma a plataforma em produto operável: uma UI única para o dev e automação de ciclo de vida via Mentors Axis. Depende de todo o restante já funcionar (identidade, credencial efêmera, rede).

## Decisões técnicas

### D1 — guacamole-common-js, não a UI stock
A UnifiedUI usa a biblioteca `guacamole-common-js` (implementação oficial do protocolo Guacamole em JS) para embutir a sessão remota num componente React/TS, renderizando o display em `<canvas>` via túnel WebSocket até o guacd. Assim a experiência vive dentro do console de vocês, com a marca IntegrAllTech, e não se herda a UI legada AngularJS.

**Esforço (honesto):** reimplementa-se o *chrome* da sessão (barra, clipboard, resize, indicador de gravação, reconexão). É projeto frontend real, não tema. Por isso vem só na Fase 4, depois de o modelo estar provado com a UI stock (rebrand) nas fases anteriores.

### D2 — Token fora do browser, mantido
O componente de sessão injeta o token OIDC no handshake do túnel, mas tokens administrativos continuam server-side (proxy). O browser fala só com o proxy do console.

### D3 — Mentors Axis como fonte de verdade e orquestrador
Provisionamento por API/IaC, versionável. Terraform para o Warpgate; API para archguard, OpenBao, Guacamole, NetBird. Onboarding/offboarding viram operações idempotentes com reconciliação (estado desejado vs. real).

### D4 — Offboarding automatizado = o clique único
`revogar_tudo(usuario)` encadeia: desabilita no archguard, invalida leases no OpenBao, remove/roles no gateway. Sem rotação de senha (garantido desde a Fase 1/2).

## Riscos e mitigações
- **Subestimar o guacamole-common-js** → faseamento explícito; começar pelo caminho feliz (uma conexão) e evoluir o chrome.
- **Deriva entre IaC e estado real** → reconciliação/idempotência (4.3).
- **Regressão do padrão token-fora-do-browser** → teste explícito (5.3).

## Fora de escopo
Agêntico e HA (Fase 5).
