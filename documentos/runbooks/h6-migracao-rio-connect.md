# Checklist H6 — Migração Rio: Connect substitui `conecta_rq` / OVPN diário

**Aceite:** dev macOS opera targets lab (e Rio com peer up) **só** com ArchGate Connect + SSO (ou lab homolog), **sem** Forti/OpenVPN do cliente no happy path.

## Pré-requisitos

- [ ] CLI `archgate` instalado (`clients/archgate-connect/install.sh`)
- [ ] Desktop opcional: `ArchGate Connect.app`
- [ ] Peer **OpenVPN** `rio-aws` **active** no VPS (AWS)
- [ ] Peer **Forti** `rio-forti` **active** no VPS **quando** precisar de LAN/Oracle on-prem  
      (e **off** no Mac — ver [forti-mac-xor-vps.md](./forti-mac-xor-vps.md))
- [ ] `archgate doctor` → bastion SSH/PG OPEN
- [ ] SSO: `~/.config/archgate/oidc.env` com client secret **ou** lab homolog

## Dia 1 — Happy path sem VPN no notebook

| # | Passo | OK? |
|---|--------|-----|
| 1 | Mac: **sem** Forti RQ / OpenVPN AS cliente (desconectar) | ☐ |
| 2 | `archgate login` (SSO) ou `login --lab` (homolog) | ☐ |
| 3 | `archgate ls` lista targets Rio (sem IPs 10.x no catálogo) | ☐ |
| 4 | `archgate go rio-aws-api-b --terminal` (ou Connect UI) | ☐ |
| 5 | `archgate go rio-lab-postgres --clipboard` (se PG apply ok) | ☐ |
| 6 | `archgate config apply` + `ssh archgate-rio-aws-api-b` | ☐ |
| 7 | Oracle: `archgate go rio-oracle-prod` → UI `/oracle` (não thin local) | ☐ |

## O que **não** fazer no dia a dia

- [ ] Não rodar `conecta_rq` / FortiClient para “chegar no Warpgate”
- [ ] Não abrir OpenVPN Connect AS no Mac para targets ArchGate
- [ ] Não copiar PEM de EC2; usar Warpgate user:target

## Quando o Mac ainda precisa de Forti

Só tarefas **fora** do modelo bastion (ex.: app que exige rota L3 no notebook).  
Antes: [desligar Forti no VPS](./forti-mac-xor-vps.md). Depois: religar peer.

## Evidence sugerida

```bash
archgate status --json
archgate doctor --json
archgate ls --json | head
# anexar em documentos/evidence/YYYY-MM-DD-h6-rio-connect.md
```

## Residual conhecido

- SSO browser E2E formal (preflight já PASS)
- Codesign do .app
- Conta de serviço Forti dedicada (não username pessoal)
- Targets PG “pending apply” no inventário

**Status H6:** checklist publicado; adoção diária = preencher este doc por operador.
