# Proposal — Add Org Credential Broker

## Why

A IntegrAllTech concentra, entre pessoas e gestores, **contas corporativas espalhadas**: Google Cloud, Google Play, Apple App Store Connect, e admins dos produtos (ArchFlow, ArchGuard, Vendax, Gestor, BrainSentry, Alçada, etc.). Senhas, URLs e ownership vivem em cofres pessoais, chat e memória — frágil para offboarding, auditoria e operação remota.

O ArchGate já é a **plataforma de acesso privilegiado** (archguard + OpenBao + Manager + bastion). Falta um módulo explícito para **contas da casa** (não targets de cliente), com checkout, TTL e dual-control — sem transformar o Connect em password manager local e sem violar a CONSTITUTION (tokens admin fora do browser; política no control plane).

## What Changes

- **Capability `org-credential-broker`:** inventário de contas org, armazenamento OpenBao, checkout com motivo/TTL, dual-control P0, auditoria.
- **Módulo no ArchGate Manager** (ADR-009 / ADR-013): UI e APIs server-side.
- **Políticas OpenBao** sob `secret/data/org/…` (cloud, store, product).
- **Permissões archguard / console** (`org_accounts:*`).
- **Estratégia paralela** de redução de senha compartilhada (OIDC nos produtos; IAM individual nas lojas).
- **Runbooks** de inventário, checkout e break-glass.

## Impact

| Item | Efeito |
|------|--------|
| **Nova capability** | `org-credential-broker` |
| **ADR** | [ADR-013](../../../adr/ADR-013-org-credential-broker.md) (proposto) |
| **Superfície** | ArchGate Manager (primário); Connect **não** no MVP |
| **Depende de** | Manager OIDC + OpenBao app token (CP-4); archguard grupos |
| **Não muda** | Warpgate targets de cliente; Connect RDM de infra |
| **Fora de escopo MVP** | Autofill browser genérico; proxy HTTP para GCP/Play/Apple; vault no endpoint |

## Success metrics

| Métrica | Alvo |
|---------|------|
| Contas P0 no inventário Manager | 100% das listadas no aceite |
| Checkout P0 com dual-control | Obrigatório ou waiver registrado |
| Offboarding | Usuário desabilitado no archguard não faz checkout |
| Reveal sem audit | Zero (todo reveal gera evento) |
| Senha no Connect localStorage/keychain app | Zero |

## Sequência

Ondas **OCB-0 … OCB-4** no design/tasks — implementável em paralelo ao Connect Onda 3, **sem** bloquear bastion de cliente.
