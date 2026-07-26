# ArchGate Connect — auto-update (F5 scaffold)

| Campo | Valor |
|-------|--------|
| Status | Scaffold (check-only) |
| Data | 2026-07-26 |
| Dependência | **Developer ID + notarize** para distribuição e update binário |

## O que existe agora

| Peça | Estado |
|------|--------|
| Manifest de versão | `clients/archgate-connect/version-manifest.json` |
| Check no app | Menu **⋯ → Verificar atualização** |
| CLI | `archgate version` / `archgate version --json` |
| Package local ad-hoc | `scripts/package-macos.sh` |
| Notarize | [archgate-connect-macos-notarize.md](./archgate-connect-macos-notarize.md) |
| Tauri updater plugin | **Não ligado** (exige artefatos assinados + chave minisign) |

## Manifest

```json
{
  "latest": {
    "version": "0.2.0",
    "macos": { "signed": false, "notarized": false, "dmg": null }
  },
  "download_page": "https://github.com/edsonmartins/archgate/releases"
}
```

Override no desktop:

```bash
# build-time
VITE_CONNECT_VERSION_URL=https://console.archgate.com.br/connect/version.json
```

## Fluxo alvo (quando org tiver Developer ID)

1. CI: `package-macos.sh` com `SIGN_IDENTITY` + `--notarize`  
2. Publicar DMG + `latest.json` (formato Tauri updater) no GitHub Releases ou CDN  
3. Gerar par de chaves minisign; pubkey em `tauri.conf.json` → `plugins.updater`  
4. Habilitar `tauri-plugin-updater` + permissão no capability  
5. App: check em background + prompt “Instalar atualização”  
6. Só então `signed: true` / `notarized: true` no manifest  

## Política até lá

- Operadores usam build **ad-hoc** de host confiável  
- “Verificar atualização” **informa** se há versão nova; **não** baixa binário  
- Nunca auto-update de artefato não notarizado em macOS de produção  

## Smoke

```bash
# manifest fetch
curl -sS https://raw.githubusercontent.com/edsonmartins/archgate/main/clients/archgate-connect/version-manifest.json | python3 -m json.tool

# suite
bash deploy/validation/smoke-onda3-connect.sh
```
