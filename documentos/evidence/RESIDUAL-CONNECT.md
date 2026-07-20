# ArchGate Connect — residual tracker

Atualizado: 2026-07-20 (pós SSO E2E + H6 expanded)

## Fechado

| Item | Evidence / artefato |
|------|---------------------|
| MVP CLI + desktop | repo `clients/archgate-connect` |
| SSO browser E2E | `2026-07-19-archgate-connect-sso-e2e.md` **PASS** |
| H6 lab + expanded | `2026-07-20-h6-connect-lab-path.md`, `2026-07-20-h6-connect-expanded.md` |
| Token exchange confidential | Basic + secret sync oidc.env |
| Keychain / Win-Linux docs / tray / scroll / `go` | commits em main |
| Warpgate SSH targets apply (72) | PASS (targets já existiam) |
| Package + codesign ad-hoc / Apple Development | `scripts/package-macos.sh` |

## Aberto (não bloqueia lab Connect)

| ID | Item | Bloqueio |
|----|------|----------|
| **R2** | **Notarize oficial** (Gatekeeper terceiros) | Sem **Developer ID Application** (só Apple Development no Mac) |
| **R3** | H6 “dia operacional” sem VPN cliente | Processo humano / hábito |
| **R4** | Forti VPS **off** enquanto Mac usa Forti | Correto (XOR); religar quando Mac desconectar |
| **R5** | Conta serviço Forti/OVPN | Ops |
| **R6** | authorized_keys AWS via PEM + PG pending apply | Ops (`RIO_AWS_PEM=… ./scripts/72-…`) |

## Comandos

```bash
# SSO
archgate login

# H6 lab
archgate login --lab --user YOU
archgate doctor && archgate ls && archgate config apply

# Package local (Development ID se disponível)
SIGN_IDENTITY="Apple Development: …" ./scripts/package-macos.sh

# Notarize (quando tiver Developer ID)
SIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=archgate \
  ./scripts/package-macos.sh --notarize

# Forti VPS off (Mac usando Forti)
# remote: systemctl disable --now archgate-connector-forti@rio-forti
```
