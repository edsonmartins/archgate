# Capability — operator-desktop-connect

## Requirements

### Requirement: Bastion-only access

The operator client SHALL route privileged access only through ArchGate bastion endpoints (Warpgate, Guacamole, console Oracle UI). It SHALL NOT configure customer Forti/OpenVPN/WireGuard as the default path.

#### Scenario: No customer VPN materialization

- **WHEN** the operator uses ArchGate Connect happy path
- **THEN** no customer VPN profile is installed and no customer RFC1918 routes are added by Connect

### Requirement: Catalog by identity

The client SHALL list only connections authorized for the authenticated operator (tenant/roles).

#### Scenario: List connections

- **WHEN** operator is logged in
- **THEN** `archgate ls` / tray list shows catalog entries without internal target IPs

### Requirement: SSH via Warpgate

#### Scenario: SSH connect

- **WHEN** operator runs `archgate ssh <target>` (or tray Connect on SSH target)
- **THEN** OpenSSH is invoked against bastion host/port with `user:target` syntax

### Requirement: SSH config materialization

#### Scenario: config apply

- **WHEN** operator runs `archgate config apply`
- **THEN** Host entries are written under a managed path (e.g. `~/.ssh/config.d/archgate`) pointing only at the bastion

### Requirement: Doctor

#### Scenario: doctor

- **WHEN** operator runs `archgate doctor`
- **THEN** the tool reports reachability of bastion endpoints and auth status without requiring customer VPN

### Requirement: Desktop tray

#### Scenario: tray MVP

- **WHEN** operator opens ArchGate Connect tray
- **THEN** they can login, see connections, and trigger connect/open for a selected target
