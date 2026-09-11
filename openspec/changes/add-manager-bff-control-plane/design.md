# Design

## Camadas

1. **BFF** valida sessão ArchGuard, `org_id`, membership e permissão da ação.
2. **Idempotency repository** persiste `(org_id, actor, method, path, key,
   body_hash, response)` em PostgreSQL/Redis compartilhado.
3. **Audit outbox** grava o evento na mesma transação da mutação e publica
   depois do commit; payloads sensíveis são redigidos.
4. **Job runner** executa operações longas com estados monotônicos e lock por
   `job_id`/`Idempotency-Key`.

## Respostas

- `401`: sessão ausente/inválida;
- `403`: permissão ou tenant incompatível;
- `409`: mesma chave com corpo diferente;
- `202`: job aceito;
- `503`: dependência indisponível, sem execução parcial.

O browser recebe apenas metadados e resultados autorizados. Credenciais de
targets, tokens de serviço, CSR e segredos ficam no servidor.
