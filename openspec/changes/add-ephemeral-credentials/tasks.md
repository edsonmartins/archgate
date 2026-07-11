# Tasks — Add Ephemeral Credentials (Fase 2)

## 1. OpenBao — base
- [x] 1.1 Subir OpenBao **lab single-node** (file storage) — `deploy/openbao/deploy.sh` (HA Raft = prod futuro)
- [x] 1.2 Unseal: chaves em `/root/archgate/bootstrap.env` (fora do git); lab threshold 1  
  - `deploy.sh` unseala após create + opcional `INSTALL_SYSTEMD=1` → `systemd/install-timer.sh`  
  - `archgate-openbao-unseal.timer` a cada **2 min** (recovery pós-recreate) — **PASS** 2026-07-10
- [x] 1.3 Auditoria file em `/var/lib/archgate/openbao/audit`
- [x] 1.4 Policy `archgate-operator-ephemeral` + `OPENBAO_APP_TOKEN`

## 2. SSH Secrets Engine (CA)
- [x] 2.1 SSH engine + CA gerada (`ssh/config/ca`)
- [x] 2.2 Role `lab-user` TTL 15m / max 30m, principal `labuser`
- [x] 2.3 Alvo lab `archgate-lab_ssh-ca` com `TrustedUserCAKeys` (2026-07-10)
- [x] 2.4 Login com certificado efêmero **PASS** (`SSH_CERT_LOGIN_OK`)

## 3. Database Secrets Engine (PostgreSQL)
- [x] 3.1 Database engine montado
- [x] 3.2 Config `archgate-lab` → Postgres `.110` / `archgate_lab` via `openbao_admin`
- [x] 3.3 Role `lab-readonly` TTL 30m / max 2h
- [x] 3.4 Criação + **revoke lease** remove acesso **PASS** (`smoke-ephemeral.sh`)

## 4. Integração com Warpgate
- [ ] 4.1 Warpgate solicitar cert SSH ao OpenBao no connect — **bloqueado** nativo (warp-tech/warpgate#2105); emissão cert via API OK
- [x] 4.2 **Bridge DB:** broker atualiza target com user/senha efêmeros (`broker-warpgate-db.sh`) — senha longa do `archgate_lab` **substituída em runtime** no target `rio-lab-postgres`
- [x] 4.3 Operador acessa DB via Warpgate com credencial dinâmica OpenBao — **PASS** `smoke-broker-warpgate.sh` (2026-07-10)
- [ ] 4.4 SSH via Warpgate só com cert CA — pendente suporte client-cert no Warpgate / broker de key

## 5. Políticas e revogação
- [x] 5.1 TTLs lab: SSH 15m / DB 30m
- [x] 5.2 Revogação de lease DB validada
- [x] 5.3 Emissão amarrada a identidade Kanidm (OIDC/JWT auth no OpenBao) — **PASS** `smoke-kanidm-jwt.sh` (2026-07-10): client `openbao`, role `archgate-operator` bound a `archguard_users@id…`, DB dynamic + SSH CA

## 6. Validação de ponta a ponta
- [x] 6.1 DB path: target `rio-lab-postgres` usa user OpenBao (não `archgate_lab` fixo) após broker — SSH targets ainda password lab
- [x] 6.2 Revoke lease remove role no Postgres; re-issue restaura lab
- [x] 6.3 Audit file local de emissão (lab)

## Scripts
- `deploy/openbao/deploy.sh` (+ unseal + install systemd)
- `deploy/openbao/systemd/install-timer.sh` — unseal timer 2m + broker 20m
- `deploy/openbao/bootstrap-engines.sh`
- `deploy/openbao/bootstrap-kanidm-auth.sh` + `smoke-kanidm-jwt.sh` **PASSED** 2026-07-10
- `deploy/openbao/smoke-ephemeral.sh` **PASSED**
- `deploy/openbao/broker-warpgate-db.sh` + `smoke-broker-warpgate.sh` **PASSED** 2026-07-10
