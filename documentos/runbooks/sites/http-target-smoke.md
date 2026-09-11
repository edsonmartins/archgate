# Smoke — target HTTP(S) via Warpgate

## Pré-requisitos

- Site com target `protocolo: https` (ou `http`) no inventário
- Host/porta alcançáveis **do connector** (não do notebook)
- Apply no console (secrets via `secret_ref` se precisar de basic auth no WG)

## Inventário (exemplo)

```yaml
targets:
  - nome: rio-grafana
    engine: warpgate
    protocolo: https
    host: 10.0.12.40
    port: 3000
    roles: [tenant-rio-quality]
    notas: Observabilidade AWS
```

## Apply

Console → Sites → Apply targets **ou** server fn `applySiteTargetsFn`.

Validação de código: host e port obrigatórios para protocolo HTTP.

## Operador

UnifiedUI / snippets HTTP:

1. Abrir URL pública do Warpgate com target (ver `frontend/unified-ui` launch `http-browser`)
2. SSO archguard
3. Sessão gravada no WG

## Checklist PASS

- [ ] Target aparece no catálogo BFF `/api/unified/v1/connections`
- [ ] Browser carrega app interno sem IP na barra do operador
- [ ] Operador de outro tenant não vê o target
