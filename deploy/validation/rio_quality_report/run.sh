#!/usr/bin/env bash
# Wrapper — run from monorepo root or any cwd.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
exec python3 -m deploy.validation.rio_quality_report "$@"
