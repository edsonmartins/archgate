# ADR-009A — Nome de produto: ArchGate Manager

- **Status:** Aceito
- **Data:** 2026-07-20
- **Emenda a:** [ADR-009](./ADR-009-control-plane-admin-console.md)
- **Relacionado:** ADR-005 (nome ArchGate), ADR-006 (UnifiedUI), ADR-008A (Connect)

## Contexto

O control plane admin (ADR-009) já roda em `console.archgate.com.br` (`archguard-console`).  
Na conversa de produto e no canal **Connect** (operador), falta um **nome de produto** estável para a superfície de administração — “Control Plane” é jargão técnico; “ArchGuard Console” confunde com o módulo de identidade.

## Decisão

1. O nome de **produto** do console admin é **ArchGate Manager**.
2. **ArchGuard** permanece o **IdP e módulo de identidade**, baseado no fork do Casdoor.
3. O código e o OIDC client podem continuar `archguard-console` no curto prazo; a **fachada** (UI, docs, runbooks) fala **ArchGate Manager**.
4. Fronteira de canais:

| Produto | Persona | Função |
|---------|---------|--------|
| **ArchGate Manager** | Super / Tenant Admin | Configurar plataforma (sites, gateways, segredos, identidade, auditoria) |
| **ArchGate Connect** | Operador (desktop) | Abrir sessões embutidas via bastion |
| **UnifiedUI** | Operador (browser) | Catálogo + sessão web (Guac) |

5. Manager **não** embute sessão RDP/SSH do dia a dia (Connect / UnifiedUI).  
   Pode exibir deep-links / snippets (`archgate go <target>`) para o operador.
6. Toda configuração suportada da plataforma deve estar disponível no Manager. Consoles
   nativos dos engines são superfícies internas de diagnóstico/break-glass, não produtos.

## Consequências

- Docs e UI: “ArchGate Manager” no title/sidebar/login.  
- Narrativa: *Manager configura o portão; Connect/UnifiedUI passam por ele; ArchGuard confere quem é.*  
- Deploy e API paths existentes permanecem; rename de client OIDC = mudança coordenada futura (não bloqueia marca).

## Fora de escopo

- App desktop admin separado.  
- Rewrite do console.  
- Renomear repositório `archguard` neste ADR.
