# ArchGate Connect — residual tracker

Atualizado: 2026-07-20

## Fechado

| Item | Status |
|------|--------|
| CLI + desktop MVP (H0–H5) | done |
| OIDC refresh + re-login | done |
| `archgate go` dispatcher | done |
| UI scroll lista | done |
| System tray + ad-hoc codesign | done |
| Keychain + Win/Linux doc + notarize pipeline | done |
| **SSO browser E2E** | **PASS** — `documentos/evidence/2026-07-19-archgate-connect-sso-e2e.md` |
| **H6 lab path** (catalog/doctor/print-ssh bastion-only) | **PASS** — `documentos/evidence/2026-07-20-h6-connect-lab-path.md` |
| Token exchange confidential client (Basic + secret sync) | done |

## Ainda aberto (ops / Apple / processo)

| ID | Item | Como fechar |
|----|------|-------------|
| **R2** | Notarize oficial | Developer ID Application + `notarytool` profile + `package-macos.sh --notarize` |
| **R3** | H6 dia-a-dia sem FortiClient/`conecta_rq` | Operador preenche checklist [h6-migracao-rio-connect.md](../runbooks/h6-migracao-rio-connect.md) |
| **R4** | Forti VPS vs Mac | Religar `archgate-connector-forti@rio-forti` quando não usar Forti no notebook |
| **R5** | Conta serviço Forti/OVPN | Ops |
| **R6** | PG targets apply / chaves WG gestor | Ops |

## Estado peers (último check)

| Peer | Status |
|------|--------|
| Forti `rio-forti` | inactive (Mac usando Forti) |
| OpenVPN `rio-aws` | active (`tun0`) |
