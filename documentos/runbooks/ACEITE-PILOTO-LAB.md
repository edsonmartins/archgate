# Checklist de aceite — Piloto lab ArchGate

**Objetivo:** definir de forma **pass/fail** o que significa *lab finalizado* (piloto usável), sem confundir com produção multi-cliente nem com Fases 3a/4/5 da especificação completa.

| Campo | Valor |
|-------|--------|
| Ambiente | Staging / lab IntegrAllTech (`192.168.1.180`) |
| Data do checklist | 2026-07-11 (exec. automatizada) |
| Executor | Grok Build (host runtime) |
| Revisor | _pendente assinatura humana_ |
| Resultado global | ☐ **PASS** · ☐ **FAIL** · ☑ **PASS com waiver** |
| Evidência | [`sites/smoke-evidence-2026-07-11-aceite-piloto.md`](./sites/smoke-evidence-2026-07-11-aceite-piloto.md) |

### Escopo deste aceite

**Inclui:** identidade + bastion lab + OpenBao lab + control plane + inventário Axis + ≥1 caminho operador bastion-first.

**Não inclui (fora do “lab finalizado”):** UnifiedUI, orquestração full de pessoas, HA, Oracle, peer VPN de cliente em produção, SIEM, NetBird.

### Como marcar

| Símbolo | Significado |
|---------|-------------|
| ✅ | PASS — evidência anexada ou linkada |
| ❌ | FAIL — bloqueia aceite global |
| ⚠️ | WAIVER — falha conhecida, aceita por escrito (motivo + prazo) |
| ⬜ | Não executado |

**Regra de aceite global**

- **PASS:** todos os itens **obrigatórios** (bloco 1–4) ✅ e nenhum ❌ sem waiver.
- **PASS com waiver:** obrigatórios ✅ ou ⚠️, e waivers listados na seção final.
- **FAIL:** qualquer obrigatório ❌ sem waiver aprovado.

---

## 0. Pré-condições de ambiente

| # | Critério | Como verificar | Evidência | Resultado |
|---|----------|----------------|-----------|-----------|
| 0.1 | Swarm runtime saudável (core services 1/1) | `docker service ls` — traefik, archguardd, console, warpgate, guacamole, openbao | colar saída ou print | ⬜ |
| 0.2 | OpenBao **unsealed** | `bao status` ou UI `/secrets` | sealed=false | ⬜ |
| 0.3 | Timer unseal ativo | `systemctl list-timers \| grep openbao-unseal` | timer listado | ⬜ |
| 0.4 | Axis Spring UP | `curl -sS http://127.0.0.1:9031/actuator/health` → `{"status":"UP"}` | saída curl | ⬜ |
| 0.5 | Console responde HTTPS | `https://console.archgate.com.br` (login) | print ou HTTP 307/200 | ⬜ |

**Bloqueio:** se 0.x falhar, não seguir para 1–4.

---

## 1. Identidade e SSO (obrigatório)

| # | Critério | Como verificar | Evidência | Resultado |
|---|----------|----------------|-----------|-----------|
| 1.1 | Login console via archguard OIDC | Abrir console → login → dashboard | print sessão | ⬜ |
| 1.2 | Operador lab autentica no Warpgate (SSO ou user de teste) | Login em `https://wg.archgate.com.br` | print / log | ⬜ |
| 1.3 | Portão Guacamole (oauth2-proxy) exige identidade | Abrir `https://guac.archgate.com.br` sem sessão → redirect IdP | print | ⬜ |
| 1.4 | OpenBao JWT (archguard) configurado | `/secrets` mostra auth jwt **ou** `smoke-archguard-jwt.sh` PASS | log smoke ou print | ⬜ |
| 1.5 | Offboarding IdP | Desabilitar user de teste no archguard → próximo login SSO falha em console **ou** WG | nota do teste | ⬜ |

**Critério do bloco:** 1.1–1.4 obrigatórios; 1.5 pode ⚠️ se só documentado e reexecutado em janela controlada.

---

## 2. Bastion e acesso operador (obrigatório)

Referência: `endpoints-staging.md`, `cliente-operador-multi-os.md`, smoke `deploy/validation/smoke-operator-access.sh`.

| # | Critério | Como verificar | Evidência | Resultado |
|---|----------|----------------|-----------|-----------|
| 2.1 | SSH via Warpgate (lab) sem VPN de cliente no notebook | `ssh -p 2222 'OPERADOR:rio-lab-ssh@HOST'` ou smoke script | log com hostname do alvo | ⬜ |
| 2.2 | Postgres via Warpgate (lab) | psql/DBeaver `OPERADOR:rio-lab-postgres` @ host:55432 `sslmode=require` → `select 1` | log ou print | ⬜ |
| 2.3 | Isolamento tenant | Operador Rio **não** alcança target Marra (e vice-versa) | log negado / smoke tenant | ⬜ |
| 2.4 | Credencial de alvo não exposta ao operador | Operador não recebe senha root/alvo no fluxo normal | checklist + observação | ⬜ |
| 2.5 | Sessão browser SSH (Guac) lab | Conexão `lab-ssh-browser` (ou equivalente) abre shell | print | ⬜ |
| 2.6 | Gravação / audit de sessão (WG e/ou Guac) | Arquivo de recording ou trilha no admin | path ou print | ⬜ |

**Critério do bloco:** 2.1–2.4 obrigatórios. 2.5–2.6 ⚠️ se lab sem UI Guac no dia, com reteste agendado.

---

## 3. Control plane admin (obrigatório)

| # | Critério | Como verificar | Evidência | Resultado |
|---|----------|----------------|-----------|-----------|
| 3.1 | Módulo Sites lista inventário (SoT Postgres) | `/sites` — **≥1** site; badge SoT `postgres` se disponível | print | ⬜ |
| 3.2 | Inventário alinhado ao Axis | Contagem sites ≈ proprietários Axis (lab: **6**) ou subset documentado | print Sites + Axis | ⬜ |
| 3.3 | Sync Axis orquestra | UI **Mentors Axis** → Sincronizar: site + archguard `tenant_*` + (se WG OK) role | print “Última orquestração” | ⬜ |
| 3.4 | Gateways: listar targets/roles (admin) | `/gateways` Warpgate tab sem erro de API | print / API do pod | ✅ |
| 3.5 | Apply site → gateway | Site com target `warpgate` → **Sincronizar gateways** → target existe no WG | log apply / path admin OK | ✅ |
| 3.6 | Segredos OpenBao (leitura admin) | `/secrets` health unsealed + mounts/JWT ou leases | print | ⬜ |
| 3.7 | Plataforma | `/platform` mostra serviços e contagens (sites / Axis / WG) | print | ⬜ |
| 3.8 | Tenant deny-by-default | User **sem** `tenant_*` e sem super-admin **não** vê todos os sites | teste com user viewer | ⬜ |
| 3.9 | Seed não roda em GET | GET list sites não cria dados sozinho; seed só POST admin | observação / código aceito | ⬜ |

**Critério do bloco:** 3.1–3.3, 3.6–3.8 obrigatórios. 3.4–3.5: resolvidos em 2026-07-11 (`WARPGATE_CONNECT_HOST` + SNI; ver evidência § Fix Warpgate).

---

## 4. Conectividade e modelo ADR-008 (obrigatório do piloto)

| # | Critério | Como verificar | Evidência | Resultado |
|---|----------|----------------|-----------|-----------|
| 4.1 | Anti-padrão documentado | Runbook deixa claro: **não** VPN cliente + SSH direto no IP do alvo | link runbook | ⬜ |
| 4.2 | Lab overlay / piloto connector | Serviços piloto (ssh e/ou ovpn/connector) 1/1 **ou** waiver | `docker service ls` | ⬜ |
| 4.3 | **≥1 site** com stack ≠ `a_confirmar` | Em `/sites`, stack wireguard\|openvpn\|openfortivpn\|lab_overlay\|… | print ficha | ⬜ |
| 4.4 | **≥1 site** com ≥1 target inventariado | Target host/port/engine preenchidos | print | ⬜ |
| 4.5 | **≥1 caminho ponta a ponta** bastion → alvo de site | SSH ou PG via Warpgate até host documentado do site | log | ⬜ |
| 4.6 | (Desejável) Peer VPN lab OpenVPN | `archgate-site-piloto_ovpn-srv` 1/1 + smoke connector | log smoke | ⬜ |

**Critério do bloco:** 4.1, 4.3, 4.4, 4.5 obrigatórios para “piloto lab”.  
4.5 é o **critério de ouro**: se falhar, o lab **não** está finalizado.

---

## 5. Segurança e higiene lab (obrigatório leve)

| # | Critério | Como verificar | Evidência | Resultado |
|---|----------|----------------|-----------|-----------|
| 5.1 | Sem `LAB_SSH_PASSWORD` no apply de targets | Código / env console sem fallback global | `grep` ou inspeção env | ⬜ |
| 5.2 | OpenBao: preferência APP_TOKEN em lab documentada | Env tem `OPENBAO_APP_TOKEN`; root só com `ARCHGATE_LAB` | env keys (sem valores) | ⬜ |
| 5.3 | Secrets de alvo não no formulário de site | UI sites não pede senha VPN/alvo persistida | observação | ⬜ |
| 5.4 | Activity log em mutações relevantes | Sync Axis ou upsert site gera entrada de audit | print audit | ⬜ |

---

## 6. Itens **explícitamente fora** do aceite lab (não bloqueiam)

Marcar só para rastreio; **não** entram no PASS/FAIL do piloto lab.

| # | Item | Pacote futuro | Resultado rastreio |
|---|------|---------------|--------------------|
| 6.1 | UnifiedUI catálogo operador | Fase 4 | ⬜ n/a |
| 6.2 | Provision/revoke pessoas Axis→archguard | Fase 4 | ⬜ n/a |
| 6.3 | Offboarding multi-componente (WG+Bao+Guac) | Fase 4 | ⬜ n/a |
| 6.4 | OpenBao HA / auto-unseal KMS | Fase 5 | ⬜ n/a |
| 6.5 | Oracle credential proxy | Fase 3a | ⬜ n/a |
| 6.6 | Peer VPN **cliente real** (contrato) | Pós-piloto | ⬜ n/a |
| 6.7 | RDP Windows real | Host Windows | ⬜ n/a |
| 6.8 | Cert SSH nativo Warpgate→OpenBao | Upstream #2105 | ⬜ n/a |
| 6.9 | Guacamole OIDC nativo Code+PKCE | Guac 1.7+ / UI | ⬜ n/a |
| 6.10 | NetBird / malha self-hosted | Mesh | ⬜ n/a |

---

## 7. Scripts e evidências de referência

| Teste | Comando / local |
|-------|-----------------|
| Smoke operador | `WG_HOST=192.168.1.180 bash deploy/validation/smoke-operator-access.sh` |
| Sync inventário CLI | `bash deploy/mentors-axis/sync-tenants-cli.sh` |
| JWT OpenBao | `bash deploy/openbao/smoke-archguard-jwt.sh` |
| Broker DB | `bash deploy/openbao/smoke-broker-warpgate.sh` |
| Endpoints | `documentos/runbooks/endpoints-staging.md` |
| Evidência histórica smoke | `documentos/runbooks/sites/smoke-evidence-2026-07-10.md` |

Anexar evidências em:  
`documentos/runbooks/sites/smoke-evidence-YYYY-MM-DD.md` (copiar modelo abaixo).

---

## 8. Waivers

| # item | Motivo | Aprovador | Prazo reteste |
|--------|--------|-----------|---------------|
| 1.1, 1.5 | Login OIDC / offboarding interativo não automatizados | _pendente_ | 7 dias |
| 2.5, 2.6 | Guac sessão gráfica + recording | _pendente_ | 7 dias |
| 5.2, 5.4 | Root token lab residual; audit UI | _pendente_ | 14 dias |
| ~~3.4, 3.5~~ | ~~Admin API WG do pod~~ — **fechado** 2026-07-11 (CONNECT_HOST + SNI) | — | — |

---

## 9. Resultado final

| Campo | Valor |
|-------|--------|
| Obrigatórios ✅ | _n_ / _n_ |
| Obrigatórios ⚠️ | _lista_ |
| Obrigatórios ❌ | _lista_ |
| **Decisão** | ☐ PASS · ☐ PASS com waiver · ☐ FAIL |
| Assinatura executor | |
| Assinatura revisor | |
| Data | |

### Definição formal

> **Lab finalizado** = blocos **0–5** com todos os **obrigatórios** em ✅ (ou ⚠️ com waiver assinado), **incluindo 4.5** (um acesso ponta a ponta bastion→alvo de site documentado), e blocos **6.x** explicitamente **fora de escopo** deste aceite.

---

## Apêndice A — Modelo de evidência rápida

```markdown
# Smoke evidence — YYYY-MM-DD

Executor:
Ambiente: 192.168.1.180

## 0.x services
(paste docker service ls filtered)

## 2.1 SSH
command:
output:

## 2.2 Postgres
command:
output:

## 3.x control plane
sites count:
axis sync:
platform:

## 4.5 E2E site
site slug:
target:
result:

## Decisão
PASS | PASS c/ waiver | FAIL
```

---

## Apêndice B — Estado conhecido do lab (referência, não substitui o teste)

Atualizar quando o aceite for executado.

| Área | Estado típico pós-implementação 2026-07 |
|------|------------------------------------------|
| Core Swarm | traefik, archguard, console, wg, guac, bao 1/1 |
| Axis | Spring 1/1; stub 0/0 |
| Sites PG | 6 clientes Axis (taf, rio_quality, …) |
| Stack sites | majoritariamente `a_confirmar` até ops preencher |
| WG roles via sync CLI | pode falhar se console não alcança admin API WG |
| CP-5 deploy automático | só hints — não é critério de PASS do lab |

---

*Documento de aceite do piloto lab — ArchGate. Não cobre Fases 3a/4/5.*
