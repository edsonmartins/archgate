# RustGuac static session-flow trace

Baseline: RustGuac `v1.9.7`.

## Actual flow

```text
authenticated POST /api/sessions
  → api::create_session
  → SessionManager::create_session
  → raw target credentials become guacd connection parameters
  → guacd::connect_and_handshake
  → pending Session stored in an in-memory HashMap

authenticated POST /api/ws-ticket
  → WsTicketStore::create(identity)
  → random UUID ticket, 30-second TTL, in-memory HashMap

GET /ws/{session_id}?ticket=...
  → optional_auth consumes ticket
  → ws_handler checks only operator+ for pending owner session
  → take_guacd_stream transitions Pending → Active
  → proxy_ws_guacd bridges WebSocket ↔ guacd
  → guacd output is teed to local `{session_id}.guac`
  → disconnect updates local DB history and applies file rotation
```

## What is reusable

- Guacamole instruction framing and bounded carry buffering.
- Bidirectional WebSocket↔guacd proxy and cancellation model.
- guacd handshake/join mechanics.
- Origin/Host CSWSH check.
- Connection state transition and pending-session timeout pattern.
- Guacamole recording tee and rotation algorithms.
- SSH tunnel host-key pinning pattern.

## Gaps that block whole-process adoption

1. **Ticket is not session-bound.** It contains only `AuthIdentity`; no
   `session_id`, tenant, audience, `pcid`, grant, IP/device binding or policy.
2. **Owner binding is incomplete.** A valid operator identity can claim a
   pending session if its UUID is known; `ws_handler` does not compare the
   identity with `created_by`.
3. **Invalid tickets fall through.** Optional auth continues to API key/session
   cookie authentication, and a legacy `?key=` API-key query path remains.
4. **Ticket/session state is in memory.** It is neither multi-instance safe nor
   restart tolerant.
5. **Session creation accepts raw credentials.** Target password/private key
   are part of `CreateSessionRequest`; ArchGate must accept only an opaque
   credential lease/reference resolved server-side.
6. **Authorization is local role hierarchy.** It has no tenant-active,
   membership, `acr`, grant or OpenFGA decision contract.
7. **Recording durability is insufficient for PAM.** Local file plus JSON
   sidecar has no checksum, chain/manifest, fsync guarantee, durable completion
   event, WORM export or `pcid`.
8. **History/auth/storage are coupled to SQLite and Vault modules.** These
   duplicate ArchGate control-plane responsibilities.
9. **Full binary brings 474 locked transitive crates.** Supply-chain and patch
   burden is significant.

## Preliminary decision

Adopting the RustGuac binary unchanged is **no-go**. The leading option is a
small ArchGate-owned Apache-2.0 session-gateway crate that reuses or ports only
the guacd protocol, proxy, framing and recording primitives behind ArchGate
contracts. A maintained narrow fork remains a fallback only if extraction
proves substantially more expensive.

