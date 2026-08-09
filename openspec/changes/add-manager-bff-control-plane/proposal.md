# Contrato BFF do Manager

## Objetivo

Padronizar mutações administrativas do ArchGate Manager com autorização por
ação, idempotência compartilhada, auditoria transacional e jobs assíncronos.

## Fora de escopo

- Não expor tokens administrativos ao browser.
- Não mover regras de identidade para o ArchGate.
- Não usar a store em memória do webhook legado como mecanismo de HA.

## Critérios de aceite

1. Toda mutação declara a permissão e o tenant que será avaliado.
2. Repetição idempotente não duplica efeitos externos.
3. Toda decisão gera evento de auditoria redigido.
4. Operações longas retornam `202` e um job isolado por organização.
