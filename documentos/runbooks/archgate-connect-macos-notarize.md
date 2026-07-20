# ArchGate Connect — macOS packaging & notarization

## Current state (local)

| Step | Status |
|------|--------|
| `tauri build` → `.app` + `.dmg` | OK |
| Ad-hoc codesign (`codesign -s -`) | OK via `scripts/package-macos.sh` |
| Apple Development identity on this Mac | Present (`Apple Development: edson martins …`) |
| **Developer ID Application** | **Required for distribution** — not present yet |
| notarytool profile `archgate` | **Not configured** |

Ad-hoc / Development signing is fine for **your** Mac. Gatekeeper on other machines needs **Developer ID + notarize**.

## Quick local package

```bash
cd clients/archgate-connect
./scripts/package-macos.sh
open dist/ArchGate\ Connect.app
```

## Official distribution (when Team has Developer ID)

### 1. Prerequisites

- Apple Developer Program membership  
- Certificate **Developer ID Application** in login keychain  
- App-specific password or API key for Notary  

```bash
security find-identity -v -p codesigning
# expect: "Developer ID Application: Your Org (TEAMID)"
```

### 2. Store notary credentials (once)

```bash
# App Store Connect API key (recommended)
xcrun notarytool store-credentials "archgate" \
  --apple-id "you@company.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
# or --key /path/AuthKey_XXX.p8 --key-id XXX --issuer UUID
```

### 3. Build + sign + notarize

```bash
export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="archgate"   # name from store-credentials
cd clients/archgate-connect
./scripts/package-macos.sh --notarize
```

The script will:

1. Build CLI sidecar + Tauri release  
2. `codesign --options runtime --sign "$SIGN_IDENTITY"`  
3. Submit `.dmg` or `.zip` of `.app` to notarytool  
4. `stapler staple` on the artifact  

### 4. Verify

```bash
spctl --assess --type execute -vv "dist/ArchGate Connect.app"
codesign -dv --verbose=4 "dist/ArchGate Connect.app"
xcrun stapler validate "dist/ArchGate Connect.app"
```

## Residual until Developer ID

- Cannot complete notarize on CI/laptop without Team credentials  
- Document this runbook; run steps when identity is issued  
- Continue shipping **unsigned/ad-hoc** only to operators who already trust the build host  

## Security notes

- Never commit `.p8`, app-specific passwords, or `oidc.env` secrets  
- Notary credentials live in keychain profile only  
