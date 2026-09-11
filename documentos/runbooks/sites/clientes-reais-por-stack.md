# Inventário — clientes reais por stack de VPN

> **Objetivo:** saber, por cliente/site, **qual VPN o connector deve usar**  
> (OpenVPN · WireGuard · openfortivpn) e o estado de migração para o modelo ArchGate.  
> **Não** listar senhas, `.ovpn` nem chaves aqui — só metadados.

| Atualizado | 2026-07-17 (W2 inventário) |
|------------|---------------------------|
| **Admin visual** | [admin-clientes-sites.md](../admin-clientes-sites.md) → `console…/sites` |
| Guia técnico | [conectividade-vpn-clientes.md](./conectividade-vpn-clientes.md) |
| Lab vs real | Lab = [INVENTARIO.md](./INVENTARIO.md) § sites staging |
| Exceções notebook | [vpn-user-exceptions.md](./vpn-user-exceptions.md) |
| Template ficha | [cliente-site.template.yaml](./cliente-site.template.yaml) |

---

## 1. Legenda

| Campo | Valores |
|-------|---------|
| `stack` | `wireguard` · `openvpn` · `openfortivpn` · `cloudflare_tunnel` · `mixed` · `a_confirmar` |
| `tipo` (ADR-008) | `connector_peer` · `tunnel_agent` · `vpn_user_exception` |
| `estado` | `não_iniciado` · `inventariado` · `connector_lab` · `connector_prod` · `exceção_ativa` |
| `prioridade_migração` | `P0` (bloqueia operação) · `P1` · `P2` · `ok` |

**Regra:** o operador **nunca** usa a stack do cliente no notebook no fluxo padrão.

---

## 2. Matriz mestre (clientes / sites conhecidos)

Preencher `stack` e `tipo` com o time comercial/ops. Valores iniciais = o que o monorepo já sabe.

| # | Cliente | Slug / tenant | Site | stack | tipo ADR-008 | estado | Prioridade | Ficha | Notas |
|---|---------|---------------|------|-------|--------------|--------|------------|-------|-------|
| 1 | **Rio Quality** | `rio_quality` / `tenant_rio_quality` | lab IntegrAllTech | `lab_overlay` | `tunnel_agent` | connector_lab | ok (lab) | [lab-rio-quality.yaml](./lab-rio-quality.yaml) | SoT inventariado; não é VPN prod |
| 2 | **Rio Quality** | `rio_quality` / `tenant_rio_quality` | **produção** | **`a_confirmar`** | **`a_confirmar`** | não_iniciado | **P0** | [reais/rio-quality.yaml](./reais/rio-quality.yaml) | W0-B / homolog; CF Tunnel candidato |
| 3 | **Grupo Marra** | `grupo_marra` / `tenant_grupo_marra` | lab IntegrAllTech | lab overlay | `tunnel_agent` | connector_lab | ok (lab) | [lab-grupo-marra.yaml](./lab-grupo-marra.yaml) | Isolação uat-op-b |
| 4 | **Grupo Marra** | `grupo_marra` / `tenant_grupo_marra` | **produção** | **`a_confirmar`** | **`a_confirmar`** | não_iniciado | **P1** | [reais/grupo-marra.yaml](./reais/grupo-marra.yaml) | W2-SITE02 2º site real |
| 5 | AJ Rorato | `aj_rorato` | produção | `a_confirmar` | a_confirmar | não_iniciado | P2 | template | Axis SoT |
| 6 | Credicoamo | `credicoamo` | produção | `a_confirmar` | a_confirmar | não_iniciado | P2 | template | Axis SoT |
| 7 | Fiomar | `fiomar` | produção | `a_confirmar` | a_confirmar | não_iniciado | P2 | template | Axis SoT |
| 8 | Mentors Informática | `mentors_informatica_ltda` | produção | `a_confirmar` | a_confirmar | não_iniciado | P2 | template | Axis SoT |
| 9 | TAF | `taf` | produção | `a_confirmar` | a_confirmar | não_iniciado | P2 | template | Axis SoT |
| 10 | Piloto connector | lab | lab | `wireguard` (lab) | `tunnel_agent` | connector_lab | ok (lab) | [lab-piloto-connector.yaml](./lab-piloto-connector.yaml) | Path WG isolado |

### Contagem por stack (produção — atualizar ao preencher)

| Stack | # sites produção | Clientes (quando confirmado) |
|-------|------------------|------------------------------|
| `wireguard` | 0 confirmados | — |
| `openvpn` | 0 confirmados | — |
| `openfortivpn` | 0 confirmados | — |
| `cloudflare_tunnel` | 0 confirmados (Rio Quality **candidato**) | Rio Quality? |
| `mixed` | 0 | — |
| `a_confirmar` | **7+** | Rio, Marra + Axis (aj_rorato, credicoamo, fiomar, mentors, taf) |

> O time usa hoje **OpenVPN, WireGuard e openfortivpn** no parque de clientes — esta tabela existe para **atribuir cada cliente a uma linha**, não para inventar stack.

---

## 3. Visão por stack (operação connector)

### 3.1 WireGuard → preferir `connector_peer`

| Quando | Implementação ArchGate | Artefato lab |
|--------|------------------------|--------------|
| Cliente aceita peer institucional | Peer site ↔ connector | `deploy-wg-piloto-lab.sh` **PASS** |
| Produção | `wireguard-peer.example.conf` + ficha `stack: wireguard` | |

**Clientes nesta stack:** _(preencher)_  

| Cliente | Site | Endpoint / peer | Subnets alvo | Connector id | Status |
|---------|------|-----------------|--------------|--------------|--------|
| — | — | — | — | — | — |

### 3.2 OpenVPN → `tunnel_agent`

| Quando | Implementação ArchGate | Artefato lab |
|--------|------------------------|--------------|
| Cliente entrega `.ovpn` / portal | Cliente OpenVPN **institucional** no connector | `deploy-openvpn-piloto-lab.sh` **PASS** |
| Produção | `stacks/openvpn/systemd/archgate-connector-openvpn@.service` | |

**Clientes nesta stack:** _(preencher)_  

| Cliente | Site | Profile (ref, não path secreto) | Conta serviço | 2FA? | Status |
|---------|------|----------------------------------|---------------|------|--------|
| — | — | — | — | — | — |

### 3.3 openfortivpn → `tunnel_agent`

| Quando | Implementação ArchGate | Artefato |
|--------|------------------------|----------|
| FortiGate SSL VPN | `openfortivpn` no connector | `stacks/openfortivpn/` (scaffold; E2E = 1º site) |

**Clientes nesta stack:** _(preencher)_  

| Cliente | Site | Host:port VPN | Conta serviço | OTP/2FA | Status |
|---------|------|---------------|---------------|---------|--------|
| — | — | — | — | — | — |

### 3.4 Cloudflare Tunnel (coexistência)

| Quando | Implementação | Nota |
|--------|---------------|------|
| Já existe no cliente (ex. Rio Quality na arquitetura) | `tunnel_agent` / borda complementar | Não substitui SSO bastion; task mesh 2.x |

**Clientes candidatos:** Rio Quality produção (`a_confirmar`).

### 3.5 `vpn_user_exception` (evitar)

| Cliente | Site | Stack no notebook | Motivo | Prazo migração | Registro |
|---------|------|-------------------|--------|----------------|----------|
| — | — | — | — | — | [vpn-user-exceptions.md](./vpn-user-exceptions.md) |

**Atual:** zero exceções ativas no inventário lab.

---

## 4. Checklist para fechar uma linha (`a_confirmar` → inventariado)

Para **cada** site produção:

1. [ ] Confirmar com ops/cliente: **OpenVPN / WireGuard / openfortivpn / Tunnel / misto**  
2. [ ] Preencher `stack` + `tipo` na ficha `reais/<slug>.yaml`  
3. [ ] Atualizar contagem §2 e tabela da stack §3  
4. [ ] Conta de **serviço** institucional (não usuário de dev)  
5. [ ] Subnets least-privilege  
6. [ ] Targets (SSH/DB/RDP) com host **visto pelo connector**  
7. [ ] Smoke: connector alcança alvo; operador só via Warpgate/Guac  
8. [ ] Segredos só em `/var/lib/archgate/connector/<site>/` (fora do git)  
9. [ ] Atualizar este arquivo + data no rodapé  

---

## 5. Ordem sugerida de onboarding (0.5)

| Ordem | Site | Por quê |
|-------|------|---------|
| 1 | Primeiro site com stack **confirmada** e conta de serviço pronta | Valida produção com stack já testada no lab (WG ou OpenVPN) |
| 2 | Rio Quality produção | Tenant lab maduro; Tunnel/Oracle no roadmap |
| 3 | Grupo Marra produção | Segundo tenant já modelado no archguard |
| 4 | Demais clientes OpenVPN / Forti | Usar units `stacks/*` |

---

## 6. Como adicionar um cliente novo

```bash
# 1. Copiar template
cp documentos/runbooks/sites/cliente-site.template.yaml \
   documentos/runbooks/sites/reais/<slug>.yaml

# 2. Editar: cliente, stack, tipo, subnets, targets (sem senhas)

# 3. Linha na matriz §2 deste arquivo

# 4. Tenant archguard + roles Warpgate (onboarding-cliente-site.md)

# 5. Deploy connector conforme stack:
#    wireguard  → deploy/connector/… peer
#    openvpn    → stacks/openvpn/systemd
#    openfortivpn → stacks/openfortivpn/systemd
```

---

## 7. Histórico

| Data | Mudança |
|------|---------|
| 2026-07-11 | Criação: matriz Rio Quality + Grupo Marra (prod `a_confirmar`); stacks vazias à espera de confirmação do time; lab separado |
