# Minimal ArchGate session-gateway contract

## Ownership

The BFF authorizes and creates sessions. The gateway only owns ephemeral data
plane state and recording production. It does not expose user, role, target,
credential or policy administration.

## Internal create API

`POST /internal/v1/sessions`

Authenticated with workload mTLS plus an audience-restricted service token.

```json
{
  "session_id": "018f...",
  "subject": "opaque-archguard-sub",
  "organization_id": "org_...",
  "membership_id": "mem_...",
  "pcid": "pcid_...",
  "grant_ref": "grant_...",
  "protocol": "ssh",
  "target": {
    "host": "10.20.0.15",
    "port": 22,
    "connector_id": "conn_..."
  },
  "credential_lease": {
    "reference": "lease_...",
    "expires_at": "2026-08-07T18:00:00Z"
  },
  "display": {"width": 1920, "height": 1080, "dpi": 96},
  "policy": {
    "recording": "required",
    "copy": false,
    "paste": false,
    "upload": false,
    "download": false
  },
  "expires_at": "2026-08-07T18:00:00Z"
}
```

Rules:

- Identity, tenant, `pcid` and grant are immutable after creation.
- Target host is resolved from an authorized resource; arbitrary browser hosts are rejected.
- Credential reference is opaque and resolves only on the internal channel.
- A required recording that cannot open durably makes creation fail.

Response:

```json
{
  "session_id": "018f...",
  "state": "pending",
  "websocket_ticket": "agw_...",
  "websocket_url": "wss://sessions.archgate.example/v1/ws/018f...",
  "ticket_expires_at": "2026-08-07T17:45:30Z"
}
```

## Ticket state

The raw ticket is 256 random bits. Only its SHA-256 hash is stored with:

```text
session_id, subject, organization_id, membership_id, pcid
audience = archgate-session-websocket
expires_at <= now + 30s
consumed_at = null
```

Consumption is an atomic compare-and-set. Failed, expired, mismatched or
replayed tickets are rejected without fallback to cookies or API keys.

## WebSocket API

`GET /v1/ws/{session_id}` uses `Authorization: Session <ticket>` or a
WebSocket subprotocol token. Query-string tokens are prohibited.

Checks before upgrade:

1. TLS and expected Origin/Host.
2. Ticket exists, is unexpired and unconsumed.
3. Path session equals ticket session.
4. Session subject/organization/membership match.
5. Grant and credential lease remain valid.
6. Atomic consumption succeeds.

## State machine

```text
requested → authorized → pending → connecting → active → closing → completed
                 │          │           │          │
                 └──────────┴───────────┴──────────→ denied|failed|expired
```

Every transition emits an outbox event containing session, `pcid`, subject,
organization, grant, previous/new state, reason and timestamp.

## Recording completion

The gateway flushes and closes the recording, calculates SHA-256 and size,
writes the object durably, and emits `session.recording.completed`. A session
with required recording becomes completed only after that event is durable.

## Required interfaces

```text
SessionRepository       create / transition / load / reap
TicketStore             issue / consume_atomic
AuthorizationVerifier   recheck grant and assurance
CredentialResolver      resolve / revoke lease
GuacdConnector          connect / join / cancel
RecordingSink           begin / append / complete / abort
AuditOutbox              append transition/event
```

In-memory implementations are test-only.

