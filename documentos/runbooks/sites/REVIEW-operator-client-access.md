# Review assíncrono — `add-operator-client-access-standard` (task 5.2)

**Status change:** lab-ready (2026-07-10)  
**ADR:** [ADR-008](../../../adr/ADR-008-cliente-operador-hibrido-multi-os.md)  
**OpenSpec:** `openspec/changes/add-operator-client-access-standard/`

## Pedido ao time

Ler e marcar **OK** (comentário em PR, Slack ou abaixo) se o padrão abaixo for o operacional oficial do time remoto.

### Decisões a confirmar

| # | Decisão | OK? |
|---|---------|-----|
| 1 | Acesso privilegiado **só** via bastion (Warpgate/Guac); proibido VPN+IP direto como padrão | ☐ |
| 2 | **Parte B** primária: OpenSSH + DBeaver/`psql` → Warpgate (SSH e DB) | ☐ |
| 3 | **Parte A** primária: browser para RDP/SSH web (Guacamole) | ☐ |
| 4 | Client multi-OS: Linux / macOS / Windows com os **mesmos** comandos/endpoints | ☐ |
| 5 | VPN do cliente na **config do site** (1 túnel → N operadores); VPN-user = exceção registrada | ☐ |
| 6 | Clientes oficiais: Chrome/Firefox, OpenSSH, DBeaver (ou psql) | ☐ |
| 7 | Windows smoke nativo pode ficar pendente com waiver até haver notebook Windows | ☐ |

### Leitura mínima (15 min)

1. [ADR-008](../../../adr/ADR-008-cliente-operador-hibrido-multi-os.md) — seções Decisão  
2. [cliente-operador-multi-os.md](../cliente-operador-multi-os.md)  
3. [INVENTARIO.md](./INVENTARIO.md)  
4. Opcional: rodar `bash deploy/validation/smoke-operator-access.sh` (Linux/macOS)

### Evidências lab

Ver [smoke-evidence-2026-07-10.md](./smoke-evidence-2026-07-10.md).

### Registro de sign-off

| Nome | Data | Resultado (OK / ressalva) |
|------|------|---------------------------|
| | | |
| | | |

Quando houver ≥1 OK de ops/eng, marcar task **5.2** `[x]` em  
`openspec/changes/add-operator-client-access-standard/tasks.md`.
