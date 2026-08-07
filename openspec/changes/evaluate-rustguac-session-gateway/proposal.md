# Proposal — Evaluate RustGuac as the ArchGate session gateway

## Problem

The current Fase 4 design embeds `guacamole-common-js`, but ArchGate still has
to implement session brokering, WebSocket tickets, recording lifecycle,
clipboard/file policies and OIDC-aware authorization. RustGuac already
implements much of this under Apache-2.0.

## Proposed change

Run a bounded technical evaluation and produce an ADR choosing one of:

1. adopt RustGuac as a separate session-gateway process;
2. extract selected Apache-2.0 modules behind ArchGate-owned interfaces;
3. keep the current implementation and port only documented patterns.

The evaluation must preserve ArchGuard as the only IdP, OpenFGA as the PAM
authorization plane, OpenBao as the credential authority and ArchGate Manager
as the only supported administrative console.

## Success criteria

- Reuse boundary and license obligations are explicit.
- An SSH session works through a single-use ticket without exposing an admin
  token or target credential to the browser.
- Tenant, assurance level, grant and `pcid` propagation are specified.
- The ADR includes migration, rollback, operability and ownership.

