# ArchGate Connect — residual (final)

Atualizado: 2026-07-20 closeout

## Product = **DONE** for intended lab/homolog scope

See `2026-07-20-connect-residual-closeout.md`.

## Only external gates remain

| Gate | Owner | Action |
|------|-------|--------|
| Developer ID + notarize | Apple Developer team | Issue cert → `package-macos.sh --notarize` |
| Full H6 lifestyle | Operator | Day without FortiClient/`conecta_rq` |
| Forti service account | Rio / ops | Dedicated connector identity |
| PG target DB passwords | Ops | Configure secrets in Warpgate for `rio-aws-pg-*` |

Nothing else is blocking Connect MVP ship for internal operators who install the ad-hoc `.app` or CLI from source.
