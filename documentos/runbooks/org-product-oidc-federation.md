# Federação OIDC de produtos (OCB-4)

| Campo | Valor |
|-------|--------|
| Status | Plano operacional + metadados no Manager |
| ADR | [ADR-013](../../adr/ADR-013-org-credential-broker.md) |
| IdP | Kanidm `https://id.archgate.com.br` |
| Checklist clients | [oidc-clients-checklist.md](./oidc-clients-checklist.md) |

## Objetivo

Reduzir **senhas compartilhadas** de admins de produto e lojas:

1. Dia a dia → **SSO** (Kanidm ou IdP da loja) com usuário individual  
2. Automação → **API key / SA** no OpenBao  
3. Break-glass → checkout dual-control no Manager (OCB-1/2)

## Matriz de produtos (IntegrAllTech)

| Produto | Estado alvo | Kanidm client id (proposto) | Notas |
|---------|-------------|------------------------------|--------|
| **ArchGate Manager** | `oidc_primary` | `archguard-console` | Já OIDC; break-glass só se existir admin local |
| **Vendax** | `oidc_primary` → `oidc_only` | `vendax-admin` | Registrar client no Kanidm; redirect do admin UI |
| **ArchFlow** | `oidc_primary` → `oidc_only` | `archflow-admin` | Idem |
| **BrainSentry** | `oidc_primary` → `oidc_only` | `brainsentry-admin` | Idem |
| **Gestor RQ** | `oidc_primary` → `oidc_only` | `gestor-admin` | Idem |
| **Alçada** | `oidc_primary` → `oidc_only` | `alcada-admin` | Idem |
| **App Store Connect** | `api_key_primary` | — (Apple IdP) | Users individuais + API key OpenBao |
| **Google Play** | `external_idp` | — (Google) | IAM individual; SA no OpenBao |
| **GCP** | `external_idp` | — (Google Workspace) | Sem senha compartilhada |

`federation_status` no inventário Manager reflete esta matriz.

## Checklist por produto (Kanidm OIDC)

Para cada app que suportará SSO:

1. **Criar client OAuth2** no Kanidm (`client_id` = coluna acima)  
2. **Redirect URIs** exatos do admin do produto  
3. **Scopes:** `openid profile email groups`  
4. **PKCE** se client public; secret só em secret store se confidential  
5. **Mapear grupos** (`archguard_users`, `archguard_super_admins`, ou grupo por produto)  
6. **Desligar** login local admin no happy path (deixar só break-glass)  
7. No Manager: `auth_kind=oidc`, `federation_status=oidc_primary`, `oidc_client_id=…`  
8. Secret no OpenBao = **apenas** break-glass (se ainda necessário)  
9. Smoke: login com usuário Kanidm + offboarding (disable user → sem acesso)

## Critérios de “federado”

| Nível | Critério |
|-------|----------|
| **oidc_primary** | Time entra com SSO; senha compartilhada só via checkout P0/P1 dual |
| **oidc_only** | Sem senha compartilhada; break-glass é conta pessoal de emergência ou key |
| **api_key_primary** | Automação via key; humanos via IAM individual da loja |
| **external_idp** | Google/Apple users individuais; sem “senha da empresa” no chat |
| **password_only** | Débito técnico — migrar |

## Ordem sugerida de implementação (engenharia de produtos)

1. ArchGuard/Manager (já feito) — validar padrão  
2. Vendax (maior uso operacional)  
3. Gestor RQ / Alçada  
4. ArchFlow / BrainSentry  
5. Hardening lojas (Apple API + Play/GCP IAM)

## O que o ArchGate **não** faz sozinho

- Implementar o IdP adapter **dentro** de cada produto (isso é task de cada codebase).  
- Substituir Apple/Google como IdP das lojas.  

ArchGate: **inventário, secret break-glass, dual-control, audit, e tracking** de `federation_status`.

## Smoke Manager

1. Contas da org → produtos com badge `oidc_primary`  
2. Checkout P0 ainda exige dual-control se houver secret_ref  
3. Contas `oidc_only` com secret_ref vazio: checkout devolve mensagem (sem secret)
