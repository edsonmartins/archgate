# ADR-008A — ArchGate Connect (cliente operador oficial)

- **Status:** Aceito
- **Data:** julho de 2026
- **Emenda a:** [ADR-008](./ADR-008-cliente-operador-hibrido-multi-os.md)
- **Relacionado:** ADR-006 (UnifiedUI), ADR-009 (console admin), ADR-010 (connectors), OpenSpec `add-operator-desktop-connect`

## Contexto

O ADR-008 definiu o modelo **híbrido** (browser + apps padrão apontando no bastion) e colocou um app desktop nativo **fora de escopo** das fases 1–3.

Com o control plane em produção (Hostinger) e connectors de site (Forti/OpenVPN no VPS), ficou explícito o **gap de UX**:

- o VPS resolve “como o ArchGate chega no cliente”;
- o dev ainda precisa copiar snippets SSH/psql ou manter VPN do cliente no notebook.

A expectativa operacional é um cliente no notebook que **liga no ArchGate** e materializa o acesso autorizado (como `conecta_rq` + OpenVPN faziam, mas **sem** peer VPN do cliente no endpoint).

## Decisão

### 1. ArchGate Connect é o cliente operador oficial

Entregar **ArchGate Connect**:

| Superfície | Papel |
|------------|--------|
| CLI `archgate` | Automação, scripts, CI local do dev, core testável |
| Tray desktop (Tauri) | UX diária: login, lista, conectar, status |

MVP v1 inclui **CLI + tray** (decisão de produto 2026-07-18).

### 2. É cliente do **bastion**, não VPN L3 do cliente

```
Notebook (Connect)
  → OIDC ArchGate + API catálogo
  → Warpgate / Guacamole / oracle UI (só hosts ArchGate)
  → [connectors no VPS]
  → rede do cliente
```

**Proibido no Connect:**

- instalar/configurar Forti, OpenVPN AS ou WireGuard do **cliente** no notebook como happy path;
- full-tunnel / rotas `10.0.0.0/16` ou `192.168.*` no Mac via Connect;
- armazenar PEM/senha de alvo do cliente.

### 3. Emenda ao ADR-008 §P3

O item “App desktop nativo ArchGate.app — não necessário para P0–P1” **deixa de ser a posição do produto**.

- P0–P1 do **padrão de acesso** (docs, Warpgate manual) permanecem válidos e são **fallback**.
- Connect é a **evolução P2 de produto** do mesmo modelo híbrido (Parte B automatizada + Parte A por deep link).

### 4. Contrato com UnifiedUI / BFF

Connect consome o **mesmo** catálogo de operador:

- `GET /api/unified/v1/connections`
- `GET /api/unified/v1/operator/bootstrap` (endpoints bastion + profile)

Admin continua no archguard-console (ADR-009). Operador **não** recebe IPs internos de alvo.

### 5. Stack

| Camada | Escolha |
|--------|---------|
| Core CLI | Go (`clients/archgate-connect`) |
| Desktop | Tauri 2 tray invocando/embutindo o CLI |
| Auth | OIDC Kanidm (`archgate-connect`) — device code e/ou PKCE browser |
| Tokens | `~/.config/archgate/` + keychain quando possível |

### 6. Fora do MVP v1

- Proxy Oracle `localhost:1521` com senha (usar `/oracle` + lease)
- NetBird no notebook do dev
- Auto-update assinado (pós-MVP)
- Windows/Linux tray parity (macOS first; CLI multi-OS)

## Consequências

### Positivas

- Substitui `conecta_rq` / OpenVPN Connect no fluxo diário Rio (após peer VPS).
- Offboarding = revogar identidade/token; não recolher VPN de 4 notebooks.
- Mesma auditoria Warpgate/Guac.

### Trade-offs

- Novo binário/app para manter (versão, assinatura macOS).
- Auth SSH no Warpgate ainda pode ser senha/SSO parcial — documentar e evoluir.
- Dependência de peer + targets apply (Connect sem peer só serve lab).

## Critérios de aceite

1. macOS sem Forti/OpenVPN do cliente: `archgate login` + `archgate ssh <target>` (lab ou Rio com peer up).
2. Tray lista só connections autorizadas; Connect/Open não expõe IP interno.
3. `archgate config apply` gera hosts SSH só para bastion ArchGate.
4. Doc de migração Mac → Connect publicada.
5. ADR-008 runbook atualizado com ponteiro para Connect.

## Referências

- `openspec/changes/add-operator-desktop-connect/`
- `documentos/runbooks/archgate-connect.md`
- `documentos/runbooks/cliente-operador-multi-os.md`
- `clients/archgate-connect/`
