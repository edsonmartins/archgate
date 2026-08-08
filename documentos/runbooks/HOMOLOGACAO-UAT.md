# Roteiro UAT — Homologação MVP ArchGate

| Campo | Valor |
|-------|--------|
| Plano pai | [`../PLAN-HOMOLOGACAO-MVP.md`](../PLAN-HOMOLOGACAO-MVP.md) (tarefa **F2.1**) |
| Objetivo | Revisor humano valida o produto em **≤ 30 min** |
| Ambiente | Staging lab — ver [`endpoints-staging.md`](./endpoints-staging.md) |
| Cliente piloto | **Rio Quality** (lab_overlay até F3; depois peer real) |
| Dono / revisor | **Edson Martins** |
| Duração alvo | 30 minutos (happy path) + 15 min opcionais (isolamento / Guac / admin) |
| Versão do roteiro | 0.4 |
| Data | 2026-07-11 |
| Dry-run auto | **2026-07-11** — bastion PASS (ver evidência homolog-prep §F2.7) |

---

## 0. Antes de começar

### 0.1 O que este UAT valida

- Login SSO (archguard) no **console**
- Bastion-first: **SSH** e **Postgres** via Warpgate
- Isolamento **tenant A ↛ tenant B**
- Control plane admin (sites / platform) em nível de sanidade
- (Opcional) Browser SSH via Guacamole com portão SSO

### 0.2 O que **não** valida (fora de escopo MVP)

UnifiedUI, Oracle, peer em N clientes, HA OpenBao, orquestração full de pessoas, NetBird, SIEM remoto.  
Lista completa: plano §2.2.

### 0.3 Contas de teste (F2.2 — provisionadas 2026-07-11)

Credenciais **só no runtime**: `/root/archgate/uat-credentials.env` (mode 600; **não** no git).  
Reprovisionar: `bash deploy/validation/provision-uat-users.sh`

| Persona | Usuário | archguard groups | Warpgate roles | Uso no UAT |
|---------|---------|---------------|----------------|------------|
| Admin plataforma | `uat-admin` | `archguard_users`, `archguard_super_admins` | `admin`, `archgate-operators` | Console full + bastion amplo |
| Operador A (Rio) | `uat-op-a` | `archguard_users`, `tenant_rio_quality` | `tenant-rio-quality` | SSH/PG `rio-lab-*`; **nega** marra |
| Operador B (Marra) | `uat-op-b` | `archguard_users`, `tenant_grupo_marra` | `tenant-grupo-marra` | Isolamento inverso |
| Viewer | `uat-viewer` | `archguard_users`, `archguard_viewers` | _(nenhuma)_ | Deny-by-default sites/targets |

**Auth verificada (lab):** REST archguard OK para as 4 contas; WG `uat-op-a:rio-lab-ssh` → hostname lab; `uat-op-a:marra-lab-ssh` → Permission denied.

**Regra:** operador **nunca** recebe senha do host/alvo; só identidade ArchGate / Warpgate.

### 0.4 Alvos deste UAT

| Uso | Target / host | Tenant | Nota |
|-----|---------------|--------|------|
| Lab (sempre disponível) | `rio-lab-ssh`, `rio-lab-postgres` | Rio | Smoke lab |
| Lab isolamento | `marra-lab-ssh` | Marra | Deve **falhar** para op. Rio |
| **Cliente real** (F3) | _preencher após peer_ | _piloto_ | **Obrigatório** no gate F5 |

Endpoints bastion:

| Serviço | URL / host |
|---------|------------|
| Console | https://console.archgate.com.br |
| archguard | https://id.archgate.com.br |
| Warpgate UI | https://wg.archgate.com.br |
| Warpgate SSH | `wg.archgate.com.br:2222` ou `192.168.1.180:2222` |
| Warpgate Postgres | `wg.archgate.com.br:55432` / `192.168.1.180:55432` · `sslmode=require` |
| Guacamole | https://guac.archgate.com.br |

Snippets: [`snippets/ssh-warpgate.example`](./snippets/ssh-warpgate.example), [`snippets/dbeaver-warpgate-postgres.example`](./snippets/dbeaver-warpgate-postgres.example).

### 0.5 Materiais do revisor

- [ ] Browser (Chrome/Firefox/Edge)
- [ ] OpenSSH 8+ (`ssh -V`)
- [ ] `psql` **ou** DBeaver
- [ ] Credenciais persona Admin + Operador A (e B se for testar isolamento)
- [ ] Este runbook + endpoints-staging

---

## 1. Happy path — Operador A (≤ 15 min)

### 1.1 Login console (SSO)

| # | Ação | Resultado esperado | ☐ |
|---|------|--------------------|---|
| 1 | Abrir https://console.archgate.com.br | Redirect ou tela de login archguard | ☐ |
| 2 | Autenticar como **Operador A** / Admin | Dashboard / app carrega sem erro 5xx | ☐ |
| 3 | Abrir `/platform` (se Admin) ou módulo visível | Serviços principais “up” ou status legível | ☐ |

**Falha bloqueante:** não entra no console → **NÃO APTO** até corrigir OIDC/rede.

### 1.2 SSH via Warpgate

Substitua `OPERADOR` e `TARGET` (lab UAT: `uat-op-a` + `rio-lab-ssh`; real: conforme F3).

```bash
# senha em /root/archgate/uat-credentials.env → UAT_PASS_uat_op_a
ssh -p 2222 'uat-op-a:rio-lab-ssh@192.168.1.180'
# ou
ssh -p 2222 'uat-op-a:rio-lab-ssh@wg.archgate.com.br'
```

| # | Ação | Resultado esperado | ☐ |
|---|------|--------------------|---|
| 1 | Conectar SSH | Shell no alvo (ou prompt intermediário WG OK) | ☐ |
| 2 | `hostname` e `whoami` | Hostname **do alvo** (não do notebook); user de sessão do target | ☐ |
| 3 | Anotar marker | Ex.: `UAT_SSH_$(date +%s)` no histórico / evidência | ☐ |
| 4 | Sair | `exit` limpo | ☐ |

**Critério de ouro (F5):** o alvo deve ser host do **cliente piloto** quando F3 estiver feito. Até lá, lab `rio-lab-ssh` serve para dry-run.

### 1.3 Postgres via Warpgate

```bash
# Exemplo psql (lab)
PGPASSWORD='SENHA_DO_OPERADOR_WG' psql \
  "host=192.168.1.180 port=55432 user=OPERADOR:rio-lab-postgres dbname=archgate_lab sslmode=require" \
  -c 'select 1 as uat_ok;'
```

Ou DBeaver: host/porta do bastion, user `OPERADOR:TARGET`, SSL require — ver snippet.

| # | Ação | Resultado esperado | ☐ |
|---|------|--------------------|---|
| 1 | Conectar | Conexão aceita | ☐ |
| 2 | `select 1` | Retorna `1` | ☐ |
| 3 | Observar user da sessão (se exposto) | Prefixo dinâmico OpenBao (`v-…`) **ou** user broker — **não** senha DBA do cliente no notebook | ☐ |

---

## 2. Isolamento tenant (≤ 5 min)

Com **Operador A** (Rio / tenant A):

```bash
# Deve FALHAR (Permission denied / unauthorized)
ssh -p 2222 'uat-op-a:marra-lab-ssh@192.168.1.180'
```

| # | Ação | Resultado esperado | ☐ |
|---|------|--------------------|---|
| 1 | SSH para target do tenant B | **Negado** | ☐ |
| 2 | SSH de novo para target do tenant A | **OK** | ☐ |

Opcional: repetir com Operador B no sentido inverso.

---

## 3. Admin control plane (≤ 7 min) — persona Admin

| # | Ação | Resultado esperado | ☐ |
|---|------|--------------------|---|
| 1 | `/sites` | Lista sites; piloto inventariado se F3 feito | ☐ |
| 2 | Abrir site piloto / Rio | Stack, targets, aba connector legíveis | ☐ |
| 3 | `/gateways` (Warpgate) | Lista targets/roles **sem** erro de API | ☐ |
| 4 | `/secrets` ou health OpenBao | Unsealed / mounts legíveis | ☐ |
| 5 | (Opcional) Sync Axis | Mensagem de orquestração sem stack trace | ☐ |

---

## 4. Guacamole browser (opcional no MVP — ≤ 5 min)

| # | Ação | Resultado esperado | ☐ |
|---|------|--------------------|---|
| 1 | https://guac.archgate.com.br sem sessão | Redirect IdP (302 portão) | ☐ |
| 2 | Login archguard | Entra no Guac (sem segundo login ideal) | ☐ |
| 3 | Abrir conexão SSH autorizada | Shell no browser | ☐ |
| 4 | (Se disponível) Confirmar recording | Path ou UI de gravação documentado na evidência | ☐ |

Se falhar só o Guac e SSH/PG desktop OK → **ressalva**, não bloqueio automático do MVP (ver plano §2).

---

## 5. Offboarding smoke (≤ 5 min) — com Admin IdP

| # | Ação | Resultado esperado | ☐ |
|---|------|--------------------|---|
| 1 | Disable / lock user de teste no archguard | Conta inativa | ☐ |
| 2 | Tentar SSO console ou novo login WG | **Falha** de autenticação/autorização | ☐ |
| 3 | Reabilitar user de UAT | Login volta a funcionar | ☐ |

Não executar em conta de produção/pessoal.

---

## 6. Folha de resultado (revisor)

| Bloco | Resultado | Notas |
|-------|-----------|-------|
| 1.1 Console SSO | ☐ PASS · ☐ FAIL · ☐ N/A | |
| 1.2 SSH bastion | ☐ PASS · ☐ FAIL | Lab / Cliente real: _______ |
| 1.3 Postgres bastion | ☐ PASS · ☐ FAIL · ☐ N/A | |
| 2 Isolamento | ☐ PASS · ☐ FAIL | |
| 3 Admin CP | ☐ PASS · ☐ FAIL · ☐ Parcial | |
| 4 Guac | ☐ PASS · ☐ FAIL · ☐ Skip | |
| 5 Offboarding | ☐ PASS · ☐ FAIL · ☐ Skip | |

### Decisão do revisor

| Campo | Valor |
|-------|--------|
| Data | |
| Revisor | |
| Tempo total | ___ min |
| Decisão | ☐ **APTO** · ☐ **APTO com ressalvas** · ☐ **NÃO APTO** |
| Ressalvas / bugs | |
| Evidências (prints, logs, paths) | |
| Assinatura | |

Transcrever a decisão também no plano: [`PLAN-HOMOLOGACAO-MVP.md` §6](../PLAN-HOMOLOGACAO-MVP.md).

---

## 7. Bugs durante o UAT

| Severidade | Regra |
|------------|--------|
| **P0** | Impede happy path (login, SSH/PG real, isolamento total quebrado) → **NÃO APTO** até fix |
| **P1** | Dói UX/admin mas há workaround → APTO com ressalva + data de fix |
| **P2** | Cosmético / nice-to-have → backlog §7 do plano |

Abrir issue no repo `edsonmartins/archgate` com label `uat` e link neste runbook.

---

## 8. Evidência sugerida

Salvar em `documentos/runbooks/sites/smoke-evidence-YYYY-MM-DD-uat.md` (copiar [`sites/smoke-evidence-TEMPLATE.md`](./sites/smoke-evidence-TEMPLATE.md)):

- Data, revisor, build/tags se souber
- Saída resumida SSH (`hostname`) e `select 1`
- Print console `/platform` ou `/sites`
- Resultado isolamento (1 linha)
- Decisão da §6 deste arquivo

---

## 9. Referências rápidas

| Doc | Uso |
|-----|-----|
| [`../PLAN-HOMOLOGACAO-MVP.md`](../PLAN-HOMOLOGACAO-MVP.md) | Plano F0–F5 |
| [`ACEITE-PILOTO-LAB.md`](./ACEITE-PILOTO-LAB.md) | Aceite lab (≠ este UAT) |
| [`cliente-operador-multi-os.md`](./cliente-operador-multi-os.md) | Detalhe multi-OS |
| [`endpoints-staging.md`](./endpoints-staging.md) | URLs/portas |
| [`onboarding-cliente-site.md`](./onboarding-cliente-site.md) | Site real (F3) |
| `deploy/validation/smoke-operator-access.sh` | Smoke automático pré-UAT |

---

## 10. Changelog

| Data | Mudança |
|------|---------|
| 2026-07-11 | Rascunho inicial (F2.1) — alvos reais ainda placeholder até F3 |
| 2026-07-11 | v0.2 — piloto Rio Quality; dono/revisor Edson; evidência homolog-prep |
| 2026-07-11 | v0.3 — F2.2 contas uat-* provisionadas (archguard+WG); matriz RBAC §0.3 |
| 2026-07-11 | v0.4 — F2.7 dry-run auto PASS (SSH/PG/isolamento 4 personas) |

---

## 11. Fricções do dry-run automatizado (F2.7)

| # | Fricção | Impacto UAT | Mitigação |
|---|---------|-------------|-----------|
| 1 | Login OIDC console / Guac **browser** não automatizado | Revisor precisa de 10–15 min manuais | Usar `uat-admin` / `uat-op-a` + senhas em `uat-credentials.env` |
| 2 | Cert visto via `127.0.0.1` = Traefik DEFAULT | Browser local pode avisar | Acessar por DNS `*.archgate.com.br` (ou aceitar lab) |
| 3 | Site Rio ainda `lab_overlay` | Não prova peer cliente real | **F3** — bloqueio de gate F5 “cliente real” |
| 4 | `uat-op-b:marra-lab-ssh` cai no mesmo container lab que rio | Isolamento é por **target/role**, não por host distinto | OK para lab; F3 usa hosts reais diferentes |
