# Proposal — Operator Client Access Standard (padrão de acesso do operador)

## Why

A equipe IntegrAllTech é **100% remota** e opera em **Linux, macOS e Windows** no notebook. Os **alvos** dos clientes são tipicamente **Linux** (com RDP Windows quando o serviço exige). Muitos clientes só expõem VPS/serviços **atrás de VPN**.

Sem um padrão explícito, o time tende a:

- instalar VPN do cliente em cada notebook;
- usar SSH/RDP/SQL **direto** no IP interno;
- espalhar credenciais de alvo no endpoint;
- fragmentar o acesso por SO (“só funciona no Windows”).

Isso anula o valor do bastion (Warpgate/Guacamole), enfraquece offboarding e multi-tenant, e conflita com a CONSTITUTION (zero target creds no dev; SSO).

Esta mudança **formaliza o padrão operacional e de produto** do cliente operador (híbrido browser + desktop, multi-OS, VPN como conectividade do site) e define os requisitos testáveis e o trabalho residual — alinhado ao **ADR-008**.

## What Changes

- **Capability `operator-client-access`:** requisitos do fluxo padrão do operador e do onboarding de site/cliente.
- **Modelo híbrido em duas partes:**
  - **Parte A (browser):** RDP/VNC/SSH web, console ArchGuard;
  - **Parte B (desktop via bastion):** OpenSSH e cliente SQL apontando ao Warpgate.
- **Multi-OS no client:** mesmo contrato de acesso em Linux, macOS e Windows (sem app proprietário ArchGate obrigatório nas fases 1–3).
- **Conectividade do cliente:** VPN/túnel/connector na **config do site** (1 path de rede → N operadores SSO); VPN-user no notebook só como exceção documentada.
- **Runbooks e critérios de aceite** multi-OS e ficha de onboarding por cliente.
- **Cruzamento com 4.2 / ADR-007:** personas SSH/DB não dependem de SSO Guacamole; RDP-browser aceita gap até remediação.

## Impact

| Item | Efeito |
|------|--------|
| **Nova capability** | `operator-client-access` |
| **ADRs** | Formaliza [ADR-008](../../../adr/ADR-008-cliente-operador-hibrido-multi-os.md); referencia ADR-007, ADR-006 |
| **Depende de** | `add-identity-axis` (bastion + archguard) em operação mínima |
| **Alimenta** | `add-network-mesh` (connector/malha), `add-unified-ui-and-orchestration` (catálogo único) |
| **Não muda** | Protocol engines (Warpgate/Guac) em si; não resolve OIDC Guacamole 1.6 |
| **Fora de escopo** | App desktop nativo ArchGate; fork GUACAMOLE-2258; Oracle (ADR-001); HA |

## Success metrics

1. Operador em Linux, macOS e Windows abre target SSH de lab via Warpgate com a doc oficial.
2. Target DB (quando provisionado) via proxy Warpgate a partir de cliente SQL multiplataforma.
3. RDP ou SSH web documentado via browser (Guacamole).
4. Todo cliente onboarding tem ficha com tipo de conectividade + targets + roles.
5. Anti-padrão (VPN + acesso direto) explícito e exceções rastreadas.
