# W0 — Execução (lab → homologação MVP)

| Campo | Valor |
|-------|--------|
| Plano 100% | [`../PLAN-PRODUTO-100.md`](../PLAN-PRODUTO-100.md) onda **W0** |
| Plano MVP | [`../PLAN-HOMOLOGACAO-MVP.md`](../PLAN-HOMOLOGACAO-MVP.md) F0–F5 |
| UAT revisor | [`HOMOLOGACAO-UAT.md`](./HOMOLOGACAO-UAT.md) |
| Validação auto | `bash deploy/validation/w0-validate.sh` (no runtime) |

---

## Ordem de trabalho

```text
1. w0-validate.sh          (auto — baseline verde)
2. W0-A browser humano     (você — ~30 min)
3. W0-B peer Rio real      (você + cliente — calendário)
4. UAT formal + assinatura (§6 MVP)
```

---

## Parte 1 — Automático (ops)

No host `192.168.1.180` (root):

```bash
cd /root/archgate/repo   # ou path do monorepo
bash deploy/validation/w0-validate.sh
# Contas UAT (se ainda não existirem):
# bash deploy/validation/provision-uat-users.sh
# Senhas: /root/archgate/uat-credentials.env  (mode 600)
```

Critério: `FAIL=0`. Skips de PG/UAT são aceitáveis se explicados.

**Deploy console** (activity log fix — scrub sqlite vazio + `/platform` força migrate):

```bash
# rsync archguard-console → /root/archgate/archguard-src/archguard-console
bash deploy/archguard/deploy-console.sh
```

---

## Parte 2 — Humano browser (W0-A) — **você**

Credenciais: `source /root/archgate/uat-credentials.env` no runtime (não commitar).

| ID | Ação | Conta | Evidência |
|----|------|-------|-----------|
| W0-A01 | https://console.archgate.com.br → login OIDC → dashboard | `uat-admin` e `uat-op-a` | print |
| W0-A02 | https://guac.archgate.com.br → SSO → conexão SSH browser | `uat-op-a` | print / sessão |
| W0-A03 | Disable user teste no Kanidm → novo SSO falha → reabilitar | admin IdP | nota |
| W0-A04 | Mutação (salvar site ou sync Axis) → ver em `/audit` ou activity | `uat-admin` | print |
| W0-A05 | Confirmar cadeado TLS válido no browser (DNS público) | — | observação |
| W0-A06 | Data-alvo UAT + assinar F1.9 no plano MVP | — | doc |
| W0-A07 | Rodar `HOMOLOGACAO-UAT.md` completo e §6 | revisor | assinatura |

---

## Parte 3 — Peer Rio Quality (W0-B)

Ficha produção: [`sites/reais/rio-quality.yaml`](./sites/reais/rio-quality.yaml)  
Lab (enquanto peer não existe): [`sites/lab-rio-quality.yaml`](./sites/lab-rio-quality.yaml)  
Onboarding peer: [`../../deploy/connector/onboarding-cliente-peer.md`](../../deploy/connector/onboarding-cliente-peer.md)

### Checklist capturar com o cliente

- [ ] Stack VPN: `wireguard` | `openvpn` | `openfortivpn` | `cloudflare_tunnel` (+ misto?)
- [ ] Endpoint / conta de serviço (sem senha no git — só ref OpenBao)
- [ ] Subnets dos targets (SSH/PG/Oracle…)
- [ ] Hosts reais (IP/DNS **internos**, não publicar ao operador)
- [ ] Janela de manutenção para peer
- [ ] Contato ops Rio

### Depois do peer

1. Preencher `sites/reais/rio-quality.yaml` (`inventariado: true`, stack ≠ `a_confirmar`).
2. Import/upsert no console `/sites`.
3. Deploy connector (`deploy/connector/…` conforme stack).
4. Apply targets Warpgate (secrets `TARGET_SECRET_*`).
5. E2E: `uat-op-a:rio-…@wg` → hostname **real**.
6. Evidência `sites/smoke-evidence-YYYY-MM-DD-cliente-piloto.md`.

Até o peer existir, o dry-run lab (`rio-lab-ssh`) **não** fecha W0-B.

---

## Estado conhecido (lab) — atualizado 2026-07-17

| Item | Status |
|------|--------|
| Bastion SSH/PG + isolamento UAT | ✅ auto (`w0-validate`) |
| Personas `uat-*` | ✅ |
| Portão Guac SSO | ✅ |
| WG admin API console | ✅ |
| Backup/restore PG | ✅ |
| `w0-validate.sh` | ✅ **PASS=19 FAIL=0** |
| Console redeploy (activity log) | ✅ |
| Offboarding e2e | ✅ **PASSED** |
| Console sessão UAT (test-login lab) | ✅ `w0-console-session.sh` PASS=16 |
| Guac SSO + sessão API + ACL | ✅ `w0-guac-session.sh` PASS=7 |
| Guac visual (pixels no browser) | ⬜ opcional revisor |
| Assinatura UAT formal §6 | ⬜ humano (W0-A06/A07) |
| Peer Rio real | ⬜ **cliente (Parte 3)** |
| SSH ops notebook → `.180` | ✅ `id_ed25519` (ssh-add keychain) |

### Console session (lab)

```bash
# no runtime (E2E login lab — já costuma estar ligado após w0-console-session)
bash deploy/validation/w0-console-session.sh
# Desligar após UAT formal se quiser:
# docker service update --env-rm ARCHGUARD_E2E_LOGIN archgate-id_archguard-console
```

---

## Definition of Done W0

- [ ] `w0-validate.sh` FAIL=0  
- [ ] W0-A01–A07 (ou waiver assinado no plano MVP)  
- [ ] W0-B05 E2E host real **ou** waiver de negócio “homolog lab only”  
- [ ] `PLAN-HOMOLOGACAO-MVP.md` §6 assinado  
