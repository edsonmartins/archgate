# Tasks — ArchGate Connect

## 0. Spec

- [x] 0.1 ADR-008A
- [x] 0.2 OpenSpec proposal/design/spec
- [x] 0.3 PLAN-IMPLEMENTACAO Fase H
- [x] 0.4 Runbook archgate-connect + migração

## 1. CLI Go

- [x] 1.1 Scaffold `clients/archgate-connect`
- [x] 1.2 `login` (device stub + file token) / `logout` / `status`
- [x] 1.3 `ls` / `doctor` (mock + API)
- [x] 1.4 `ssh` / `config apply|remove` / `db` / `open`
- [x] 1.5 OIDC PKCE browser (`internal/oidc`) — archguard sem device_code
- [x] 1.6 `login --lab` fallback

## 2. BFF

- [x] 2.1 `GET /api/unified/v1/operator/bootstrap`
- [x] 2.2 Bearer userinfo + lab token path
- [x] 2.3 OIDC client `archgate-connect` no archguard (confidential + scopemap via SA; secret em bootstrap.env / `~/.config/archgate/oidc.env`)

## 3. Tray Tauri

- [x] 3.1 Scaffold tray UI + invoke CLI (janela Tauri MVP; system tray icon residual)
- [ ] 3.2 Packaging macOS .app / codesign (pós-MVP ok — .app/.dmg unsigned gerados localmente)

## 4. Validação

- [x] 4.1 Smoke mock CLI: `archgate-devops/scripts/68-smoke-archgate-connect.sh` PASS
- [ ] 4.2 Doc Windows/Linux CLI best-effort
- [x] 4.3 OIDC preflight + bootstrap live lab: `clients/archgate-connect/scripts/smoke-h4-h5.sh` + evidence `documentos/evidence/2026-07-19-archgate-connect-h4-h5.md` (SSO browser interativo residual)
- [x] 4.4 OIDC refresh + re-login on 401 (`internal/cli/session.go`)
- [x] 4.5 Dispatcher `archgate go` / `connect` (UI usa go; policy no CLI)
- [x] 4.6 Runbook Forti Mac XOR VPS + checklist H6

## 5. Residual

- [x] 5.1 System tray icon (menu bar) — hide-on-close + Abrir/Status/Sair
- [x] 5.2 Codesign ad-hoc via `scripts/package-macos.sh`; notarize pipeline doc + `--notarize` (needs Developer ID)
- [x] 5.3 SSO E2E: preflight script + interactive harness + evidence template (`smoke-sso-e2e.sh`)
- [x] 5.4 Keychain token storage (`go-keyring`; `ARCHGATE_KEYCHAIN=file` fallback)
- [x] 5.5 Windows/Linux CLI doc (`documentos/runbooks/archgate-connect-windows-linux.md`)

## 6. Still blocked on org credentials / human

- [x] 6.1 Interactive SSO evidence (`documentos/evidence/2026-07-19-archgate-connect-sso-e2e.md` — testadmin OIDC PASS)
- [ ] 6.2 Developer ID Application cert + notarytool profile → real notarize (org/Apple only)
- [x] 6.3 H6 lab-path evidence (`documentos/evidence/2026-07-20-h6-connect-lab-path.md`)
- [x] 6.4 AWS Warpgate client keys via PEM (72) + PG targets (73) + WG user testadmin
