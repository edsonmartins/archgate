#!/usr/bin/env bash
# W1-OPS02 — backup Warpgate (+ optional Guacamole) session recordings.
set -euo pipefail

OUT="${BACKUP_DIR:-/var/backups/archgate-recordings}"
STAMP=$(date +%Y%m%d-%H%M%S)
RETENTION_DAYS="${RETENTION_DAYS:-30}"
WG_SRC="${WARPGATE_RECORDINGS:-/var/lib/archgate/warpgate/recordings}"
GUAC_SRC="${GUACAMOLE_RECORDINGS:-/var/lib/archgate/guacamole/recordings}"
CONSOLE_SQLITE="${CONSOLE_SQLITE:-/var/lib/archgate/console/archguard.sqlite}"

mkdir -p "$OUT"
chmod 700 "$OUT"

archive_one() {
  local name="$1" src="$2"
  if [[ ! -d "$src" ]]; then
    echo "[skip] $name: missing $src"
    return 0
  fi
  local dest="$OUT/${name}-${STAMP}.tar.gz"
  echo "[backup] $name → $dest"
  tar -czf "$dest" -C "$(dirname "$src")" "$(basename "$src")" 2>/dev/null || \
    tar -czf "$dest" -C "$src" .
  ls -lh "$dest"
}

archive_one warpgate-recordings "$WG_SRC"
archive_one guacamole-recordings "$GUAC_SRC"

if [[ -f "$CONSOLE_SQLITE" ]]; then
  dest="$OUT/console-sqlite-${STAMP}.sqlite"
  cp -a "$CONSOLE_SQLITE" "$dest"
  ls -lh "$dest"
fi

if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] && [[ "$RETENTION_DAYS" -gt 0 ]]; then
  find "$OUT" -type f \( -name '*.tar.gz' -o -name '*.sqlite' \) -mtime "+${RETENTION_DAYS}" -delete || true
fi
echo "[backup] done stamp=$STAMP"
