# Design — RustGuac session-gateway evaluation

## Invariants

- ArchGuard is the only OIDC issuer.
- OpenFGA decides privileged-resource access and fails closed.
- OpenBao issues or resolves target credentials server-side.
- The browser receives only a short-lived single-use session ticket.
- All configuration is exposed through ArchGate Manager APIs and UI.
- RustGuac's SQLite user/admin model is not a source of truth.

## Initial module assessment — W1-01

| RustGuac area | Decision candidate | Reason |
|---|---|---|
| Guacamole WebSocket proxy | Reuse/adapt | Removes the largest missing backend portion of UnifiedUI |
| guacd protocol/session lifecycle | Reuse/adapt | Mature path for SSH/RDP/VNC and recording |
| Single-use WebSocket tickets | Reuse pattern/code | Direct match for token-out-of-browser invariant |
| Recording rotation/typescript | Reuse/adapt | Required for audit and capacity control |
| Clipboard copy/paste policy | Reuse/adapt | Required DLP control |
| RDP drive and SSH SFTP | Reuse after policy gate | Useful but must be denied by default |
| OIDC implementation | Adapt | Must consume ArchGuard claims and logout contract |
| Role hierarchy/group mapping | Replace | Authorization belongs to ArchGuard/OpenFGA |
| SQLite users/sessions | Replace | PostgreSQL and ArchGate control plane are canonical |
| Vault connection storage | Replace | OpenBao is already the credential authority |
| Built-in admin UI | Reject | ArchGate Manager is the only admin surface |
| Web-session browser automation | Defer | Valuable later; expands attack surface significantly |
| LUKS drive lifecycle | Reuse pattern | Deployment-specific; OpenBao must control material |

## Target boundary

```text
UnifiedUI
  → ArchGate BFF POST /sessions
    → ArchGuard claims + OpenFGA check + OpenBao lease
      → session-gateway issues one-time ticket
        → WebSocket Guacamole protocol → guacd → target
```

The session gateway receives an already-authorized, minimal session envelope;
it does not manage people, memberships, grants or permanent credentials.

## Open questions / measurements

1. Can RustGuac storage/auth modules be disabled cleanly without a long-lived fork?
2. What is the smallest process boundary that preserves upstream updates?
3. Does its recording path expose a durable completion event and checksum?
4. Can every WebSocket ticket be bound to session, subject, audience and TTL?
5. How does disconnect behave during BFF/gateway restart?
6. Concurrent session memory/CPU for SSH and RDP.

## Go/no-go gate

Adopt only if the spike demonstrates a narrow adapter boundary, no duplicate
IAM/secrets source, single-use ticket enforcement, session audit correlation
and an acceptable upstream maintenance strategy.

## Static-trace result

Whole-process adoption is currently **red**. RustGuac's useful data-plane code
is mixed with an in-memory session/ticket model, local RBAC, SQLite history and
Vault-backed address book. Its 30-second WebSocket ticket is genuinely
single-use, but it is identity-only rather than session-bound and an invalid
ticket falls through to legacy authentication paths.

The preferred direction for the executable spike is therefore **extract/port
minimal modules**, not deploy the upstream binary unchanged. See
`evidence/rustguac-session-flow.md`.
