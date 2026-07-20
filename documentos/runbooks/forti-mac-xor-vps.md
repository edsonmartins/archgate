# Runbook — Forti Rio Quality: Mac **XOR** VPS

> **Problema:** a conta SSL-VPN Forti RQ costuma ser **single-session**.  
> Peer no VPS (`archgate-connector-forti@rio-forti`) e FortiClient/openfortivpn no notebook **disputam a mesma sessão**.

## Regra

| Quem usa Forti RQ | Onde |
|-------------------|------|
| **ArchGate (Warpgate / Oracle via bastion)** | **VPS** `rio-forti` **ligado** · Mac **sem** Forti RQ |
| **Você no Mac (conecta_rq / FortiClient)** | **VPS Forti desligado** · Mac com Forti |

OpenVPN AWS (`rio-aws`) é **independente** — pode ficar active no VPS enquanto o Forti está off.

## Desligar Forti no VPS (liberar Mac)

```bash
cd archgate-devops
# precisa .env com ARCHGATE_HOST / SSH
source scripts/lib.sh && load_env
remote systemctl disable --now archgate-connector-forti@rio-forti
remote systemctl is-active archgate-connector-forti@rio-forti   # inactive
```

Ou via shell:

```bash
./scripts/ssh-shell.sh
systemctl disable --now archgate-connector-forti@rio-forti
```

## Religar peer Forti no VPS (depois do Mac)

1. Desconecte FortiClient / openfortivpn no Mac.  
2. No VPS:

```bash
systemctl enable --now archgate-connector-forti@rio-forti
systemctl --no-pager -l status archgate-connector-forti@rio-forti | head -20
ip -br addr show ppp0   # esperado com IP quando up
```

3. Smoke: `./scripts/65-smoke-rio-peer.sh`

## Sintomas de conflito

- VPS unit em `activating (auto-restart)` / exit 1  
- Mac openfortivpn sem `ppp0` ou queda imediata  
- “Connection terminated” nos logs do openfortivpn no VPS  

## Anti-padrões

- Deixar Forti no Mac **e** unit enabled no VPS “por precaução”  
- Usar conta `suporte.mentors*` pessoal no connector de produção sem conta de serviço dedicada  

Ver também: `docs/RIO-QUALITY-PEER.md`, `runbooks/archgate-connect.md`.
