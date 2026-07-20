# Evidence — H6 partial: Connect lab path (sem VPN cliente no happy path)

| Campo | Valor |
|-------|--------|
| **Data** | 2026-07-20 |
| **Host** | macOS darwin/arm64 |
| **CLI** | archgate 0.2.0-dev |
| **Modo** | `login --lab` (homolog) + BFF live |
| **Resultado** | **PASS** (caminho lab); SSO interativo = ver smoke-sso-e2e |

## Checks

| Check | Resultado |
|-------|-----------|
| `archgate login --lab --user h6.smoke` | OK · Warpgate `uat-op-a` · 10 connections |
| `doctor` auth / warpgate_user / catalog | OK |
| `ssh_bastion` 217.196.60.108:2222 | **OPEN** |
| `pg_bastion` :55432 | **OPEN** |
| `print-ssh rio-lab-ssh` | `uat-op-a:rio-lab-ssh@217.196.60.108` (sem IP de alvo) |
| Catálogo | 10 entries (rio-gestor, oracle, aws-*, lab-*) |

## Peers no VPS (contexto)

| Unit | Status |
|------|--------|
| `archgate-connector-forti@rio-forti` | **inactive** (Mac usando Forti — ver forti-mac-xor-vps) |
| `archgate-connector-openvpn@rio-aws` | **active** · `tun0` up |

## Critério H6

- [x] Operar catálogo + doctor + print-ssh **sem** materializar VPN cliente via Connect  
- [x] Bastion-only SSH line  
- [ ] SSO (OIDC) no lugar de lab — residual até `smoke-sso-e2e.sh --interactive` PASS  
- [ ] Dia inteiro sem `conecta_rq` / FortiClient — checklist operacional do operador  

## Comando

```bash
ARCHGATE_MOCK=0 ARCHGATE_KEYCHAIN=file archgate login --lab --user h6.smoke
archgate doctor --json
archgate ls --json
archgate print-ssh rio-lab-ssh
```
