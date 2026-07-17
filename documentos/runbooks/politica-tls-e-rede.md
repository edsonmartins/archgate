# Política TLS e rede (W1-SEC05 / W1-SEC06)

## NODE_TLS_REJECT_UNAUTHORIZED

| Ambiente | Valor | Motivo |
|----------|-------|--------|
| **Runtime Swarm (lab e W1 default)** | `NODE_TLS_REJECT_UNAUTHORIZED=0` | Dial interno a Traefik (`WARPGATE_CONNECT_HOST`) com SNI público |
| **STRICT_TLS=1** | unset (verify ON) | Quando houver CA privada confiável no trust store do pod |

```bash
# W1 harden (default mantém TLS insecure só para peer interno)
ARCHGATE_LAB=0 bash deploy/archguard/harden-console-env.sh
# quando CA interna existir:
STRICT_TLS=1 ARCHGATE_LAB=0 bash deploy/archguard/harden-console-env.sh
```

Warpgate proxy no console usa `rejectUnauthorized` coerente com essa env.

## Axis (Mentors)

| Item | Lab | W1+ |
|------|-----|-----|
| URL | rede Swarm `archgate-axis-spring:9030` | preferir rede privada / não expor public |
| mTLS | não | **desejável** antes de multi-cliente prod |
| Waiver homolog | Axis lab sem mTLS aceito | reavaliar em M2 |

Enquanto mTLS não existir: Axis só em rede overlay isolada; sem publicação Traefik pública.

## Cloudflare / borda

- TLS público em `*.archgate.com.br` via tunnel/Traefik.  
- Validar no browser do revisor (cadeado) em UAT formal.
