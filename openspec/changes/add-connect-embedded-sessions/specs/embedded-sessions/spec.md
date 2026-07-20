# Capability — embedded-sessions

## Requirements

### Requirement: Multi-session workspace

The Connect desktop app SHALL allow multiple concurrent session tabs for catalog connections without requiring an external terminal for the happy path of SSH (and Guac for RDP when available).

#### Scenario: Open SSH tab

- **WHEN** the operator activates Connect on a Warpgate SSH target
- **THEN** a session tab opens in the workspace and an embedded terminal attaches to the bastion session (or shows connecting/error state)

#### Scenario: Open Guac/RDP tab

- **WHEN** the operator activates Connect on a Guacamole/RDP target and BFF issues a tunnel
- **THEN** a session tab renders the remote display via guacamole-common-js inside the app

#### Scenario: External fallback

- **WHEN** embedded session fails or the operator chooses Open external
- **THEN** the existing launcher behavior (Terminal / browser) remains available

### Requirement: Bastion only

Embedded sessions SHALL only connect to ArchGate bastion endpoints (Warpgate SSH/PG, Guacamole, console URLs). They SHALL NOT configure customer VPN.

### Requirement: Session lifecycle

#### Scenario: Close tab

- **WHEN** the operator closes a session tab
- **THEN** the underlying PTY/tunnel is terminated

#### Scenario: Logout

- **WHEN** the operator logs out of Connect
- **THEN** all session tabs are closed and OIDC credentials cleared
