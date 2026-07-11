# Evidência smoke — operator-client-access (ADR-008 P1)

**Data:** 2026-07-10  
**Script:** `deploy/validation/smoke-operator-access.sh`  
**Bastion:** `192.168.1.180` (staging)  
**Operador lab:** `testuser` → targets `rio-lab-ssh`, `rio-lab-postgres`

| Operador SO | SSH Warpgate | DB proxy | Guac API (Parte A) | Como |
|-------------|:------------:|:--------:|:------------------:|------|
| **Linux** (runtime host) | PASS | PASS | PASS | `WG_HOST=127.0.0.1 bash smoke-operator-access.sh` no `.180` |
| **macOS** (notebook dev) | PASS | PASS | PASS | `WG_HOST=192.168.1.180 bash smoke-operator-access.sh` |
| **Windows** | pending | pending | pending | Ver procedimento abaixo |

### Linux — RESULT
```
RESULT operator_os=linux ssh=PASS db=PASS guac=PASS ts=2026-07-10T17:13:29-03:00
marker=ADR008_SMOKE_1783714408_2525016
```

### macOS — RESULT
```
RESULT operator_os=macos ssh=PASS db=PASS guac=PASS ts=2026-07-10T17:14:20-03:00
marker=ADR008_SMOKE_1783714433_4925
```

### Windows — procedimento de aceite (manual)

Ver **[windows-acceptance.md](./windows-acceptance.md)** (waiver lab + checklist).

### Isolamento multi-tenant (suporte 4.1)

```
testuser → rio-lab-ssh     = PASS (RIO_OK)
testuser → marra-lab-ssh   = PASS_ISOLATION_DENIED (Permission denied)
```
