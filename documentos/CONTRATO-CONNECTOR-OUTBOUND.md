# Contrato Connector Outbound (W2)

Contrato inicial do canal Manager ↔ connector. O connector sempre abre a conexão; o Manager não expõe porta inbound no site.

## Envelope

Cada mensagem é JSON UTF-8 com `version`, `type`, `message_id`, `connector_id`, `sent_at` e `payload`:

```json
{
  "version": 1,
  "type": "heartbeat",
  "message_id": "uuid",
  "connector_id": "connector-rio-aws",
  "sent_at": "2026-08-09T13:00:00Z",
  "payload": {}
}
```

Tipos previstos: `enroll`, `enroll_ack`, `heartbeat`, `capabilities`, `inventory`, `diagnostic`, `upgrade`, `revoke` e `error`.

## Regras de segurança

- Enrollment usa token single-use emitido pelo Manager; o token nunca vira credencial de operação.
- O connector envia CSR; o Manager só assina se o enrollment estiver válido e ainda não consumido.
- A sessão de transporte exige mTLS, `connector_id` no certificado e verificação de tenant/site.
- Heartbeat sem certificado válido, `connector_id` desconhecido ou versão incompatível é rejeitado.
- Reconnect usa backoff exponencial com jitter (1s, 2s, 4s … máximo 60s); mensagens possuem `message_id` idempotente.
- O agente aceita `CONNECTOR_HEARTBEAT_URLS` como lista de endpoints HTTPS separados por vírgula; em falha ele alterna o endpoint e mantém o backoff. `CONNECTOR_HEARTBEAT_URL` permanece como atalho de endpoint único.
- Upgrade controlado começa em modo plano: `GET/POST /v1/upgrade/plan` valida versão, URL HTTPS e SHA-256, mas não baixa nem substitui o binário. O resultado exige aprovação explícita antes de qualquer rollout.
- Revogação encerra a sessão atual e impede novo reconnect; não há fallback para token antigo.
- Payloads não carregam senhas/chaves; segredos continuam no OpenBao e só são materializados no host connector.

## Heartbeat mínimo

```json
{
  "status": "ready|degraded|revoked",
  "agent_version": "archgate-connector-agent/1.0",
  "capabilities": ["wireguard", "openvpn"],
  "uptime_seconds": 1234,
  "last_config_revision": "sha256:..."
}
```

Até a CA PKI estar configurada no OpenBao, o Manager deve responder `error.code = "pki_unavailable"` ao pedido de certificado; nunca gerar uma CA local implícita.
