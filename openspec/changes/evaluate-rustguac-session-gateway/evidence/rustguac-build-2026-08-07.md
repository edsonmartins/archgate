# RustGuac reproducible-build evidence — 2026-08-07

## Command

```bash
CARGO_TARGET_DIR=/private/tmp/archgate-rustguac-target cargo build --locked
```

Host: macOS. Baseline: RustGuac `v1.9.7`.

## macOS result

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

## Linux/amd64 result

**PASS.** GitHub Actions run `31206982431` checked out the exact revision
`a897fcc63b672907f01c74515b92ff766530f318`, built the upstream Dockerfile and
published an OCI index with SBOM and provenance:

```text
ghcr.io/edsonmartins/archgate-rustguac-spike@sha256:1252bd6a138738ce4163a7afacb4b1ae3941c5b71b2c17420e4dc8123c15e2ab
linux/amd64 manifest: sha256:d4f1d47e3b276d0b03b9613fd7af73f31c406199f52f8c5a1c330a136bab24e7
```

The macOS failure remains a valid upstream portability finding, but no longer
blocks task 2.1 or the Linux executable spike.
