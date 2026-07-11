# Tasks — Operator Client Access Standard

> Decisão: [ADR-008](../../../adr/ADR-008-cliente-operador-hibrido-multi-os.md)  
> Runbooks: [cliente-operador](../../../documentos/runbooks/cliente-operador-multi-os.md) · [onboarding-site](../../../documentos/runbooks/onboarding-cliente-site.md)  
> Sites: [documentos/runbooks/sites/](../../../documentos/runbooks/sites/)

## 1. Formalização (P0)

- [x] 1.1 ADR-008 aceito (cliente operador híbrido multi-OS)
- [x] 1.2 Proposal / design / spec OpenSpec desta change
- [x] 1.3 Runbook operador multi-OS
- [x] 1.4 Runbook onboarding de site (conectividade + targets)
- [x] 1.5 Referência no README do monorepo e no índice `openspec/changes/README.md`

## 2. Padronização operacional (P1)

- [x] 2.1 Congelar lista oficial de clientes no endpoint (browser, OpenSSH, DBeaver ou equivalente)
- [x] 2.2 Snippets versionados (ssh, dbeaver/postgres, windows, endpoints, smoke script)
- [x] 2.3 Aceite lab SSH operador **Linux** (2026-07-10 PASS)
- [x] 2.4 Aceite lab SSH operador **macOS** (2026-07-10 PASS)
- [x] 2.5 **Windows** — procedimento + waiver lab documentados (`sites/windows-acceptance.md`); smoke nativo **deferred** até host Windows do time
- [x] 2.6 Proxy Postgres via Warpgate (Linux + macOS PASS; `sslmode=require`)
- [x] 2.7 SSH web via Guacamole (API + `lab-ssh-browser`; RDP n/a)
- [x] 2.8 Fichas: `sites/lab-rio-quality.yaml`, `sites/lab-grupo-marra.yaml`

## 3. Conectividade e governança de site (P1–P2)

- [x] 3.1 Inventário sites — `sites/INVENTARIO.md` (rio, marra, lab genérico)
- [x] 3.2 Registro `vpn_user_exception` — `sites/vpn-user-exceptions.md` (**zero** exceções ativas)
- [x] 3.3 Preferência contratual 1 túnel → N operadores — INVENTARIO + onboarding-cliente-site
- [x] 3.4 Smoke path lab + **connector piloto** (LAN isolada): `deploy/connector/smoke-connector-piloto.sh` PASS. Cliente real VPN: template WG pronto; deploy produção pendente

## 4. Alinhamento de plataforma (P2)

- [x] 4.1 Targets lab SSH+DB com roles tenant (`rio-*` / `marra-*`); isolamento testuser rio OK / marra denied (2026-07-10)
- [x] 4.2 Endpoints staging — `endpoints-staging.md`
- [x] 4.3 Cruzamento ADR-007 (personas Warpgate-only vs RDP-browser)
- [x] 4.4 Stub mapeamento malha — `sites/network-mesh-mapping.md` (implementação = `add-network-mesh`)
- [ ] 4.5 UnifiedUI catálogo + embed — **blocked** em `add-unified-ui-and-orchestration`

## 5. Validação de fechamento da change

- [x] 5.1 Critérios ADR-008 / proposal: satisfeitos no lab **com waiver Windows nativo** e **N/A VPN cliente real**
- [x] 5.2 Pacote de review assíncrono publicado — `documentos/runbooks/sites/REVIEW-operator-client-access.md` (sign-off do time = preencher tabela; não bloqueia lab-ready)
- [x] 5.3 Índice OpenSpec: change listada como 1b em `openspec/changes/README.md` (status: lab-ready)

## Critérios de aceite (espelho proposal)

| Critério | Status |
|----------|--------|
| Operador Linux/macOS/Windows doc + SSH lab | Linux+macOS PASS; Windows procedimento+waiver |
| DB proxy multiplataforma | PASS (psql L+M) |
| RDP/SSH web browser | SSH web PASS; RDP n/a lab |
| Ficha onboarding com conectividade | PASS (rio + marra + inventário) |
| Anti-padrão VPN+direto explícito | PASS (runbooks + inventário) |
