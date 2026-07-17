# MFA e política de senha — operadores (W1-ID01)

| Campo | Valor |
|-------|--------|
| IdP | Kanidm (`id.archgate.com.br`) |
| Escopo | operadores humanos em produção |
| Status W1 | **documentado**; enforcement gradual |

## Política alvo (produção)

| Controle | Recomendação IntegrAllTech |
|----------|----------------------------|
| Senha mínima | Conforme account-policy Kanidm (lab: `credential-type-minimum any` em `archguard_users`) |
| MFA | **WebAuthn/Passkey preferido**; TOTP aceitável |
| Quem | Todos em `archguard_users` / `archguard_tenant_admins` / super_admins |
| Break-glass | `idm_admin` / recover — **sem** MFA de usuário final; acesso físico/ops only |
| Service accounts | Token API; sem senha interativa |

## Habilitar MFA no Kanidm (ops)

1. Login como `idm_admin` (recover se necessário).  
2. Por pessoa (UI Kanidm ou CLI tools):
   - credential update → adicionar **Passkey/WebAuthn** ou **TOTP**.  
3. (Opcional) account-policy no grupo `archguard_users`:
   - exigir segundo fator quando a versão Kanidm/policy suportar enforcement.  
4. Validar: login console OIDC e Warpgate SSO pedem 2º fator.

```bash
# exemplo CLI (tools image; precisa sessão idm_admin)
# kanidm person credential update <user>   # interativo: passkey / totp
```

## Lab vs prod

| Ambiente | MFA |
|----------|-----|
| Lab UAT (`uat-*`) | opcional (senhas em `uat-credentials.env`) |
| Operadores reais | **obrigatório** antes de multi-cliente prod |

## Checklist go-live 1º cliente

- [ ] Contas reais criadas (não só uat-*)  
- [ ] Passkey ou TOTP cadastrado  
- [ ] Login console + WG SSO testados com MFA  
- [ ] Break-glass documentado e testado em janela controlada  
