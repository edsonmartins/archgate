# Smoke evidence — YYYY-MM-DD

| Campo | Valor |
|-------|--------|
| Executor | |
| Revisor | |
| Ambiente | `192.168.1.180` (staging) |
| Checklist | `documentos/runbooks/ACEITE-PILOTO-LAB.md` |
| Decisão | PASS / PASS com waiver / FAIL |

## 0. Pré-condições

```
# docker service ls (core)
```

OpenBao sealed?  
Axis Spring health:  
Console HTTPS:

## 1. Identidade / SSO

- [ ] Console OIDC
- [ ] Warpgate auth
- [ ] Guac portão
- [ ] OpenBao JWT
- [ ] Offboarding (se executado)

Notas:

## 2. Bastion operador

### 2.1 SSH

```
command:
output:
```

### 2.2 Postgres

```
command:
output:
```

### 2.3 Isolamento tenant

```
resultado:
```

### 2.5 Guac browser (se aplicável)

## 3. Control plane

- Sites count / SoT:
- Axis sync (print ou resumo):
- Platform:
- Apply gateways (se executado):

## 4. Conectividade / E2E site

- Site slug:
- Stack:
- Target:
- Comando e resultado 4.5:

## 5. Segurança

- LAB_SSH ausente:
- APP_TOKEN OpenBao:
- Activity log:

## Waivers

| Item | Motivo | Aprovador | Prazo |
|------|--------|-----------|-------|
| | | | |

## Decisão final

**PASS** · **PASS com waiver** · **FAIL**

Assinaturas:
