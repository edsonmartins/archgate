# RustGuac evaluation baseline

| Field | Value |
|---|---|
| Local source | `/Users/edsonmartins/desenvolvimento/rustguac` |
| Commit | `a897fcc63b672907f01c74515b92ff766530f318` |
| Tag | `v1.9.7` |
| Package version | `1.9.7` |
| Repository license file | Apache License 2.0 |
| Upstream NOTICE | Not present in the evaluated tree |
| Cargo `license` metadata | Not declared in root `Cargo.toml` |

## Candidate source modules

| Concern | Files to trace first |
|---|---|
| Session model/lifecycle | `src/session.rs`, `src/api.rs` |
| WebSocket entry and bridge | `src/websocket.rs`, `src/tunnel.rs` |
| guacd protocol | `src/guacd.rs`, `src/protocol.rs` |
| Recording | `src/recording.rs` |
| Clipboard/file policy | `src/session.rs`, `src/config.rs`, `src/drive.rs` |
| Authentication boundary to replace | `src/auth.rs`, `src/db.rs` |
| Credential storage boundary to replace | `src/vault.rs` |

## License conclusion at this gate

The repository-level license permits an Apache-2.0 evaluation and potential
reuse with attribution. This is not yet approval to copy code: transitive
Cargo licenses must pass the ArchGuard/ArchGate license policy, and the final
integration must add an ArchGate NOTICE entry because upstream does not ship a
NOTICE file in this revision.

## Reproducibility

```bash
cd /Users/edsonmartins/desenvolvimento/rustguac
git rev-parse HEAD
git describe --tags --always --dirty
sed -n '1,4p' LICENSE
rg -l 'ticket|Ticket|recording|disable_copy|disable_paste|guacd|WebSocket|websocket' src -g '*.rs'
```

