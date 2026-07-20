# Evidence — H6 expanded (Connect happy path)

| Campo | Valor |
|-------|--------|
| **Data** | 2026-07-20 |
| **CLI** | archgate 0.2.0-dev |
| **Auth** | lab `h6.op` → WG `uat-op-a` |
| **Resultado** | **PASS** (bastion path) |

## Checks

| Check | Result |
|-------|--------|
| login lab + 10 connections | OK |
| doctor all checks | OK |
| print-ssh lab/aws bastion-only | OK (`217.196.60.108:2222`) |
| db rio-lab-postgres JSON/psql | OK |
| `config apply` → `~/.ssh/config.d/archgate` | OK Hosts archgate-* |
| go/open for oracle (name) | via `archgate go` → open UI |
| SSO E2E | PASS (separate evidence) |

## Peers VPS

| Peer | Status | Note |
|------|--------|------|
| Forti rio-forti | **inactive** | Mac has openfortivpn/ppp0 — XOR policy |
| OpenVPN rio-aws | **active** | tun0 up |

## Warpgate apply (72)

```text
./scripts/72-apply-rio-ssh-warpgate.sh → PASS
targets: rio-aws-api-a/b, rio-aws-obs, rio-gestor-linux, rio-lab-*
(0 new inserts — already present)
```

## Residual H6

- [ ] Operador: dia sem FortiClient/`conecta_rq` para trabalho via Connect  
- [ ] Religar Forti no VPS quando LAN/Oracle on-prem via bastion for necessário  
- [ ] PEM AWS para authorized_keys Warpgate (optional RIO_AWS_PEM)  
- [ ] PG targets “pending apply” no inventário console  
