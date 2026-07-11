# Proposal — Add Agentic Access & HA (Fase 5)

## Why

Com a plataforma completa e operável, esta fase endereça duas evoluções: **alta disponibilidade** (para operar em produção com confiança) e **acesso agêntico** — permitir que um agente de IA (ex.: OpenSRE) opere a plataforma como principal, de forma governável.

O valor central: transformar "IA com acesso privilegiado" de pesadelo em algo **auditável e reversível**. O bastion é agnóstico ao principal — o agente é apenas mais uma identidade, tratada como **não-confiável por padrão**, com a política imposta no gateway, não delegada ao raciocínio do modelo.

## What Changes

- **Alta disponibilidade:** OpenBao em HA, Kanidm com replicação, persistência externa, gateways stateless atrás do Traefik.
- **Acesso agêntico:** agente como **service account** no Kanidm, escopo mínimo.
- **JIT por incidente:** credencial efêmera via OpenBao com escopo por incidente/host.
- **HITL obrigatório** para ações mutantes/destrutivas (base: fluxo de aprovação web do Warpgate); leitura ampla pode ser automática.
- **On-behalf-of:** toda ação amarrada à service account **e** ao humano que autorizou.
- **Kill-switch:** revogar a service account no Kanidm interrompe o agente (mesmo mecanismo do offboarding).
- **Inferência local** (vLLM na RTX 3060 / Mac Mini M4) para não vazar dado de produção de cliente.

## Impact

- **Novas capabilities:** `agentic-access`, `high-availability`.
- **Componentes:** OpenSRE (service account), OpenBao/Kanidm em HA, gateways, inferência local.
- **Depende de:** Fases 1–4.
- **Postura:** read-only primeiro; write só com HITL; relaxar gates apenas após histórico/gravação comprovarem comportamento.
