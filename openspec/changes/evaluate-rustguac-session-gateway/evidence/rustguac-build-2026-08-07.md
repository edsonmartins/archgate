# RustGuac reproducible-build attempt — 2026-08-07

## Command

```bash
CARGO_TARGET_DIR=/private/tmp/archgate-rustguac-target cargo build --locked
```

Host: macOS. Baseline: RustGuac `v1.9.7`.

## Result

**FAIL** during compilation of the root binary. `src/main.rs` calls
`drive::mount_luks` and `drive::unmount_luks` on macOS, while those functions
are compiled only under `#[cfg(target_os = "linux")]` in `src/drive.rs`.

Errors: `E0425` at `src/main.rs:549`, `:668` and `:1274`.

## Interpretation

- The locked dependency graph resolves and compiles far enough to reach the
  application crate.
- The upstream binary is currently Linux-only in implementation despite not
  gating the callers correctly for non-Linux development hosts.
- This reinforces the extraction approach: guacd/proxy primitives should be a
  platform-neutral library crate; LUKS lifecycle belongs in an optional Linux
  adapter.
- Task 2.1 remains open until a pinned Linux container build succeeds.

