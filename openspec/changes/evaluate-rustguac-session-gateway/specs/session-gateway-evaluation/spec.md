# Capability — Session gateway evaluation

## Scenario: identity boundary

**WHEN** a session is requested  
**THEN** the gateway accepts identity only from an ArchGuard-validated session envelope  
**AND** it does not maintain an independent user or role source of truth.

## Scenario: authorization boundary

**WHEN** OpenFGA is unavailable or denies the tuple  
**THEN** no target credential or WebSocket ticket is issued.

## Scenario: ticket replay

**WHEN** an already-consumed or expired WebSocket ticket is presented  
**THEN** the connection is rejected and an audit event is emitted.

## Scenario: ticket/session mismatch

**WHEN** a valid unconsumed ticket is presented for another session path  
**THEN** the upgrade is rejected  
**AND** the request never falls back to another authentication mechanism.

## Scenario: owner binding

**WHEN** an operator presents a ticket issued to another subject, tenant or membership  
**THEN** the WebSocket upgrade is rejected.

## Scenario: credential confidentiality

**WHEN** a browser opens a remote session  
**THEN** browser-visible requests, responses, storage and logs contain neither
the target credential nor an administrative engine token.

## Scenario: console ownership

**WHEN** an administrator configures session, recording, clipboard or file-transfer policy  
**THEN** the supported workflow is available through ArchGate Manager.
