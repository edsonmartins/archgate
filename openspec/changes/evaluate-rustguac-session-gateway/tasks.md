# Tasks — Evaluate RustGuac session gateway

## 0. Baseline

- [x] 0.1 Confirm license and map RustGuac modules to ArchGate ownership — initial matrix in `design.md` (2026-08-07)
- [x] 0.2 Record non-negotiable ArchGuard/OpenFGA/OpenBao/Manager boundaries
- [x] 0.3 Pin evaluated RustGuac commit and record license/module evidence — `evidence/rustguac-baseline.md` (2026-08-07)
- [x] 0.4 Generate locked dependency inventory, verify transitive licenses and prepare NOTICE draft — `evidence/rustguac-license-audit.md` (2026-08-07)

## 1. Static compatibility

- [x] 1.1 Trace RustGuac session creation through WebSocket/guacd lifecycle — `evidence/rustguac-session-flow.md`
- [x] 1.2 Trace ticket generation, consumption, TTL and replay behavior — session binding gap identified
- [x] 1.3 Trace recording completion and rotation — durability gaps identified
- [x] 1.4 Identify storage/auth dependencies that must be replaced — SQLite/Vault/local RBAC rejected
- [x] 1.5 Define minimal adapter/process API and data model — `evidence/minimal-session-gateway-contract.md` (2026-08-07)

## 2. Executable spike

- [x] 2.1 Build pinned RustGuac revision reproducibly — Linux/amd64 OCI image, SBOM and provenance published by GitHub Actions (`evidence/rustguac-build-2026-08-07.md`)
- [x] 2.2 Start guacd + session gateway in isolated lab — digest-pinned VPS profile, HTTPS 200 and SSH target reachability proven (`evidence/rustguac-vps-spike-2026-08-07.md`)
- [ ] 2.3 Open one SSH session through a one-time ticket
- [ ] 2.4 Prove ticket replay is denied
- [ ] 2.5 Prove target credential and admin token are absent from browser traffic/logs
- [ ] 2.6 Capture recording and correlate it with a synthetic `pcid`
- [ ] 2.7 Measure idle/active SSH resource use and disconnect/restart behavior

## 3. ArchGate integration design

- [ ] 3.1 Specify `POST /api/unified/v1/sessions`
- [ ] 3.2 Specify ArchGuard claims and minimum `acr`
- [ ] 3.3 Specify OpenFGA check and fail-closed semantics
- [ ] 3.4 Specify OpenBao lease/revoke lifecycle
- [ ] 3.5 Specify session/recording audit events
- [ ] 3.6 Specify Manager configuration resources and screens

## 4. Decision

- [ ] 4.1 Compare adopt-process, extract-modules and current-stack options
- [ ] 4.2 Write ADR with migration and rollback
- [ ] 4.3 Update Fase 4 tasks from the accepted decision
