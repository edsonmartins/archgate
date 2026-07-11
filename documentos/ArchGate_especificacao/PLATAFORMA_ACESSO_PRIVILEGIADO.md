# ArchGate — Plataforma de Acesso Privilegiado — Documento de Arquitetura

> **Nome:** ArchGate (família Arch, irmã de ArchFlow/ArchGuard). O **ArchGuard** é o módulo de identidade dentro do ArchGate — "o Guard controla quem passa pelo Gate". Ver ADR-005. *(nome aceito, pendente checagem de marca/domínio — atenção à similaridade com AppGate)*
> **Autor:** Edson Martins — Arquiteto de Software e Soluções, IntegrAllTech
> **Versão:** 0.1 (draft fundador)
> **Data:** julho de 2026
> **Status:** proposta de arquitetura para PoC → produção

---

## 1. Contexto e problema

A IntegrAllTech cresce em número de clientes e de desenvolvedores, e com isso a gestão de acesso privilegiado às infraestruturas dos clientes virou fonte de risco e de trabalho manual. Hoje os desenvolvedores detêm diretamente credenciais sensíveis — senhas de VPN, chaves SSH, acessos a bancos e painéis dos clientes. As consequências práticas:

- **Offboarding caro e arriscado.** Quando um dev sai, é preciso rotacionar manualmente todas as senhas e chaves que ele pode ter tido acesso, em todos os clientes. Processo lento, sujeito a esquecimento e a janela de exposição.
- **Credenciais espalhadas.** Segredos vivem em máquinas de devs, gerenciadores pessoais, arquivos de configuração. Não há um ponto único de verdade nem de revogação.
- **Auditoria fraca.** Não há gravação central de o que foi feito, por quem, em qual máquina de qual cliente.
- **Escala.** O modelo atual não acompanha o crescimento do time nem do número de clientes (Rio Quality, Grupo Marra e os próximos).

O objetivo é construir uma **plataforma de acesso privilegiado no modelo bastion/gateway**, na qual o desenvolvedor **nunca recebe a credencial do alvo**. Ele se autentica na plataforma, é autorizado por cliente/tenant, recebe uma credencial **efêmera** e tem toda a sessão gravada. Offboarding passa a ser um clique — revoga-se a identidade em um lugar só, sem rotacionar senha nenhuma.

---

## 2. Objetivos e não-objetivos

### Objetivos

1. Desenvolvedor acessa máquinas remotas (SSH/RDP), bancos (PostgreSQL/Oracle), Kubernetes e painéis web dos clientes **sem jamais ver ou possuir a credencial**.
2. **Offboarding sem rotação de senha**: revogar acesso de uma pessoa (ou agente) em um ponto central, com efeito imediato.
3. **Multi-tenant**: isolamento e RBAC por cliente/tenant, alinhado ao registro do Mentors Axis.
4. **Identidade central** com SSO (OIDC), incluindo identidades não-humanas (service accounts) para agentes.
5. **Gravação e auditoria** de todas as sessões privilegiadas, self-hosted (LGPD/soberania de dados).
6. **API-first**: toda operação (provisionar usuário, conceder/revogar acesso, emitir credencial) disponível por API para orquestração pelo Mentors Axis.
7. **Self-hosted** sobre a infraestrutura da IntegrAllTech (Docker Swarm + Traefik), com dados de sessão em território nacional.

### Não-objetivos (nesta fase)

- Substituir o **UseDevKit** como plano de configuração/feature-flags das aplicações da IntegrAllTech — são camadas distintas e permanecem separadas.
- Ser uma plataforma de observabilidade/resposta a incidentes — esse é o espaço do **OpenSRE**, tratado como evolução adjacente (ver §9.4 e §15).
- Gerenciar segredos de aplicação (o app buscando sua própria senha de banco) — isso é papel do UseDevKit, não do bastion.
- Fornecer VPN de usuário final para clientes; a malha de rede aqui serve à plataforma alcançar as redes-alvo, não a substituir produtos de VPN.

---

## 3. Princípios de arquitetura

1. **Zero-credencial-no-dev.** O segredo do alvo nunca chega ao principal (humano ou agente). O gateway injeta; o principal apenas usa.
2. **Efemeridade por padrão.** Credenciais de acesso são de curta duração (certificados SSH assinados, credenciais dinâmicas de banco). Nada permanente na mão de ninguém.
3. **Política no gateway, não no principal.** Autorização e limites são impostos pela infraestrutura (Warpgate/OpenBao), não delegados ao julgamento do usuário/agente. Fundamental para o caso agêntico.
4. **Identidade é o alicerce.** Todo acesso deriva de uma identidade autenticada e autorizada. Revogar identidade = revogar acesso.
5. **Tudo auditável e reversível.** Cada sessão gravada; cada concessão rastreável a uma pessoa e a uma autorização; kill-switch central.
6. **API-first e IaC.** Provisionamento por API/Terraform, versionável, sem cliques manuais como fonte de verdade.
7. **Soberania de dados.** Gravações, logs e inferência de IA rodam on-premises/local sempre que tocarem dado de cliente.

---

## 4. Visão geral da arquitetura

A plataforma se organiza em cinco camadas, com o **Mentors Axis como plano de controle** por cima:

| Camada | Função | Componente |
|---|---|---|
| **Controle** | Registro de tenants/clientes, orquestração de provisionamento, painel operador | Mentors Axis + ArchGuard (console) |
| **Identidade** | "Quem é o principal?" — OIDC, RBAC, service accounts | ArchGuard sobre **Kanidm** |
| **Gateway** | Proxy de protocolo com injeção de credencial e gravação | **Warpgate** (SSH/HTTPS/K8s/MySQL/PostgreSQL) + **Apache Guacamole** (RDP/VNC/SSH via browser) |
| **Segredos** | Emissão de credenciais efêmeras (SSH CA, DB dinâmico) | **OpenBao** |
| **Rede** | Alcançabilidade às redes dos clientes | **NetBird** (malha WireGuard) + Cloudflare Tunnel (onde já existe) |

O fluxo do desenvolvedor entra por **um único ponto** (o console/UnifiedUI sobre ArchGuard + Mentors Axis). Tudo abaixo — Kanidm, OpenBao, Warpgate, Guacamole, NetBird — é invisível para ele.

> Diagrama de camadas: ver a versão renderizada na conversa. Esta é a "stack revisada" com ArchGuard/Kanidm no lugar do Keycloak.

---

## 5. Componentes e decisões

### 5.1 Identidade — ArchGuard sobre Kanidm

**ArchGuard** (projeto interno IntegrAllTech) é o console de gestão de identidade/acesso, construído sobre o **Kanidm** como engine de identidade. O Kanidm é um servidor de identidade moderno em Rust (MPL-2.0), com OIDC/OAuth2 + PKCE, RBAC, grupos, **service accounts** (identidades não-humanas) e autenticação forte (Passkeys/WebAuthn/TOTP).

**Por que Kanidm no lugar de Keycloak:** menor footprint, seguro por padrão, Rust, alinhado ao ecossistema; e — decisivo — a IntegrAllTech **já opera** o Kanidm via ArchGuard, encurtando a fase de identidade. O ArchGuard já traz multi-tenant com RBAC (Super Admin, Tenant Admin, Service Desk, Viewer), gestão visual de clients OAuth2, service accounts e auditoria.

**Padrão de segurança reaproveitado:** o ArchGuard já implementa o padrão que o frontend do bastion exige — sessão dupla (OIDC para operador + service account para API administrativa), com **tokens sensíveis nunca expostos ao browser** e todo acesso passando por proxy server-side com validação de path. É o mesmo princípio "o segredo nunca chega ao cliente" que sustenta a UX da plataforma.

**Limite conhecido:** Kanidm foca OIDC/OAuth2; suporte SAML é limitado. Como toda a stack de gateways aqui fala OIDC, isso não gera atrito. Kanidm também distribui chaves SSH públicas de usuários, mas isso é chave **estática** — não substitui a CA de certificados efêmeros (ver §5.3).

### 5.2 Gateways — Warpgate + Apache Guacamole

Duas peças **complementares**, não redundantes.

**Warpgate** (Rust, open-source, mantido por contratos de suporte — sem VC): bastion transparente para **SSH, HTTPS, Kubernetes, MySQL e PostgreSQL**. Não é jump host: encaminha a conexão direto ao alvo, de forma transparente ao cliente (o dev usa `ssh`/`psql` nativo). Recursos relevantes:

- SSO nativo via **OpenID Connect** + 2FA TOTP → aponta para o Kanidm.
- **Gravação de sessão** (live + replay) com UI de admin embutida.
- **RBAC** por target (usuário/grupo → host/URL).
- **Terraform provider** e **SDKs OpenAPI** autogerados → provisionamento por IaC/API a partir do Mentors Axis.
- **Fluxo de aprovação web** embutido → primitivo de HITL nativo (útil no caso agêntico).
- Modelo de chave: o Warpgate gera seu próprio par; adiciona-se **uma** pública nos alvos. Binário único, ~8 MB de RAM.
- Concessões de **acesso temporário** nativas.

**Apache Guacamole** (Java, Apache 2.0): gateway *clientless* via browser para **RDP, VNC e SSH**. Cobre o que o Warpgate não faz — sobretudo **RDP para desktops Windows** e o acesso "pelo navegador sem cliente". Arquitetura: `guacd` (daemon proxy em C) + webapp Java + `guacamole-common-js` (biblioteca JS que implementa o protocolo). Extensível por autenticação OIDC (extensão `openid`) → também aponta para o Kanidm.

**Divisão de responsabilidade:**

| Protocolo | Gateway |
|---|---|
| SSH (terminal nativo) | Warpgate |
| SSH/VNC via browser | Guacamole |
| **RDP (Windows)** | **Guacamole** |
| PostgreSQL / MySQL | Warpgate |
| **Oracle** | ver §5.3 e §16 (decisão em aberto) |
| Kubernetes | Warpgate |
| Painéis web/HTTP internos | Warpgate (HTTPS) |

### 5.3 Segredos efêmeros — OpenBao

**OpenBao** (Go, MPL-2.0, fork do Vault sob a Linux Foundation) é a **peça insubstituível** do modelo. É ele que torna "offboarding sem rotação" possível:

- **SSH Secrets Engine (CA):** assina certificados SSH de **curta duração** (TTL de minutos). O alvo confia na CA; o dev nunca recebe uma chave permanente. Revogou a autorização → o próximo certificado não é emitido → o que ele tinha expira sozinho.
- **Database Secrets Engine:** credenciais **dinâmicas** de banco, criadas sob demanda com TTL e revogadas ao fim. Cobre PostgreSQL nativamente; **Oracle** requer validação de plugin (ver §16).
- **Políticas e leases:** cada credencial tem escopo e validade; auditoria de emissão.

> **Importante:** nem o **UseDevKit** nem o **AliasVault** (cofre do ArchGuard) substituem o OpenBao aqui. UseDevKit é cofre *estático* de config de aplicação (devolve o valor ao chamador). AliasVault é cofre de senhas humanas com criptografia end-to-end. Nenhum dos dois é uma **CA que assina certificados efêmeros** — essa propriedade é exclusiva do OpenBao (ou step-ca) e é o coração do offboarding sem rotação.

### 5.4 Rede — NetBird (+ Cloudflare Tunnel)

**NetBird** (Go, BSD-3) fornece a **malha WireGuard** que dá alcançabilidade de rede às infraestruturas dos clientes, substituindo o emaranhado de VPNs avulsas. Peers nas redes-alvo + controle de acesso central. Onde já houver **Cloudflare Tunnel + Zero Trust** (caso Rio Quality), ele permanece como via de borda complementar — não se joga fora o que já funciona; integra-se.

O NetBird é infraestrutura: **não é exposto ao dev**. Ele garante que o gateway consiga *chegar* ao alvo; a autenticação e a injeção de credencial acontecem na camada de gateway.

### 5.5 Plano de controle — Mentors Axis

O **Mentors Axis** é a fonte de verdade dos clientes/tenants e o orquestrador. Ele:

- Mantém o registro de clientes (proprietários) e mapeia para tenants na plataforma.
- Dispara **onboarding/offboarding** programaticamente (provisiona no Kanidm, cria targets no Warpgate/Guacamole, configura políticas no OpenBao).
- Consolida o **painel operador** (junto ao ArchGuard) — o "single pane of glass".
- Ambos (Mentors Axis e ArchGuard) já são multi-tenant, o que facilita a costura.

### 5.6 Frontend — UnifiedUI sobre ArchGuard

O frontend é **inteiramente da IntegrAllTech**. A chave é **não herdar a UI legada (AngularJS) do Guacamole**: usa-se a biblioteca `guacamole-common-js` para embutir a sessão de RDP/SSH dentro de um componente **React 18/19 + TypeScript**, renderizando o display remoto em `<canvas>` via túnel WebSocket até o `guacd`. Assim, a experiência de sessão vive dentro do console de vocês, com a identidade visual da IntegrAllTech, e as UIs nativas de Warpgate/Kanidm/OpenBao/NetBird ficam **restritas ao admin/infra**, escondidas do fluxo do dev.

**Nota de esforço (honesta):** o caminho `guacamole-common-js` é poderoso, mas exige reimplementar o *chrome* da sessão (barra de conexão, clipboard, resize, indicador de gravação, reconexão). É projeto frontend de verdade, não tema. Para o PoC, começar com a UI stock do Guacamole (rebrand leve) valida o fluxo; a UnifiedUI React entra depois de o modelo estar provado.

---

## 6. Modelo de identidade e autorização

### Tenancy
Cada cliente da IntegrAllTech = um **tenant**. O Mentors Axis é a fonte de verdade; o Kanidm/ArchGuard reflete os tenants e seus grupos. Acesso a targets é sempre escopado por tenant.

### Papéis (RBAC)

| Papel | Escopo | Capacidades |
|---|---|---|
| Super Admin | Global | Gestão da plataforma, todos os tenants |
| Tenant Admin | Um tenant | Gestão de usuários/targets/políticas do cliente |
| Operador (dev) | Targets autorizados | Abrir sessões nos alvos permitidos; nunca vê credencial |
| Service Desk | Um tenant | Suporte, visão de sessões, sem acesso destrutivo |
| Viewer/Auditor | Definido | Leitura de logs/gravações |
| **Service Account** | Escopo estreito | Identidade não-humana (agentes); JIT + HITL para ações mutantes |

### Identidades não-humanas
Agentes (ex.: OpenSRE no futuro) são **service accounts** no Kanidm, com escopo mínimo, credenciais efêmeras via OpenBao e gate HITL obrigatório para qualquer ação mutante (ver §9.4).

---

## 7. Segredos e credenciais efêmeras — políticas

Diretrizes de TTL e escopo (a calibrar no PoC):

| Tipo | Emissor | TTL sugerido | Escopo |
|---|---|---|---|
| Certificado SSH | OpenBao SSH CA | 5–15 min | Host/target específico, principal específico |
| Credencial de banco (PostgreSQL) | OpenBao DB dinâmico | 15–60 min | Base/schema, permissões mínimas |
| Credencial Oracle | OpenBao (plugin a validar) | 15–60 min | idem — ver §16 |
| Sessão RDP/Guacamole | Injeção via gateway | Duração da sessão | Target específico |
| Token de agente (service account) | Kanidm + OpenBao | Curtíssimo, por incidente | Escopo por incidente/host |

Princípio: **menor privilégio + menor duração**. Renovação exige reautorização; nada de credencial de longa vida.

---

## 8. Modelo de rede

- **NetBird** forma a malha entre a plataforma e cada rede de cliente; peers instalados nas redes-alvo.
- Onde há **Cloudflare Tunnel** (Rio Quality), integra-se como via de borda; túnel de saída (7844) evita abrir portas de entrada.
- O gateway alcança o alvo **através** da malha; o dev nunca toca a rede diretamente.
- Segmentação por tenant na malha, para que o alcance de um cliente não vaze para outro.

---

## 9. Fluxos principais

### 9.1 Onboarding (dev novo)
1. Mentors Axis cria o usuário no Kanidm (via API), associa ao(s) tenant(s) e grupo(s).
2. Políticas de RBAC definem quais targets ele enxerga.
3. Dev faz login por OIDC no console; vê **apenas** suas conexões autorizadas.
4. Nenhuma credencial de alvo é entregue.

### 9.2 Acesso (exemplos por protocolo)
- **SSH nativo:** dev conecta ao Warpgate (`ssh usuario:target@warpgate`). Warpgate autentica via OIDC/Kanidm, pede ao OpenBao um **certificado efêmero**, injeta e encaminha ao alvo. Sessão gravada.
- **RDP (Windows):** dev abre a conexão no console; UnifiedUI (guacamole-common-js) renderiza o desktop via `guacd`; credencial injetada pelo gateway; sessão gravada.
- **Banco (PostgreSQL):** dev aponta o cliente ao Warpgate; credencial **dinâmica** do OpenBao com TTL; encerrada ao fim.
- **Web/K8s:** via Warpgate (HTTPS/Kubernetes), com SSO e gravação.

### 9.3 Offboarding — o *killer use case*
1. Mentors Axis (ou Tenant Admin no ArchGuard) **desabilita a identidade** no Kanidm.
2. SSO cai imediatamente em Warpgate e Guacamole (confiam no Kanidm).
3. OpenBao **não emite** novos certificados/credenciais para aquele principal.
4. O que ele porventura tinha **expira sozinho** em minutos (TTL curto).
5. **Zero rotação de senha.** Nenhuma senha de cliente precisa ser trocada.

### 9.4 Fluxo agêntico (OpenSRE) — evolução futura
O bastion é **agnóstico ao principal**: humano ou agente, exige autenticação, autorização, credencial efêmera e gravação. Um agente OpenSRE seria uma **service account** no Kanidm. Diferenças críticas de segurança:

- **Prompt injection é superfície de ataque.** O agente lê logs/alertas (conteúdo não-confiável); a política **tem que ser imposta no gateway** (allow-list de comandos, escopo por host, TTL mínimo, rate limit), nunca delegada ao raciocínio do modelo.
- **Blast radius.** Agente dispara muitos comandos por segundo; limites explícitos são obrigatórios.
- **On-behalf-of.** Toda ação amarrada à service account **e** ao humano que autorizou.
- **HITL obrigatório** para ações mutantes/destrutivas (o fluxo de aprovação web do Warpgate serve de base). Leitura ampla pode ser automática.
- **Kill-switch = offboarding.** Agente descarrilou? Revoga a service account no Kanidm → o próximo cert não sai → expira em minutos.
- **LGPD/local-first.** Inferência local (vLLM na RTX 3060 / Mac Mini M4) para não vazar dado de produção do cliente a APIs de terceiros.

Postura: **read-only primeiro**; write só com HITL; relaxar gates apenas após histórico/gravação comprovarem comportamento.

---

## 10. Gravação de sessão e auditoria (LGPD)

- **Warpgate** grava sessões (live + replay) nativamente; **Guacamole** grava sessões gráficas.
- Armazenamento **self-hosted**, em território nacional (soberania/LGPD).
- Auditoria: quem, quando, qual target, qual tenant, qual autorização.
- Atenção: default do Warpgate é **SQLite**; para HA/escala, apontar para **PostgreSQL externo** (ver §12).
- Retenção e acesso às gravações regidos por política; consentimento do cliente para acesso a ambientes que contenham dado pessoal.

---

## 11. Integração com Mentors Axis — contratos de API

O Mentors Axis orquestra as demais peças. Superfícies disponíveis:

| Peça | Superfície de integração |
|---|---|
| Kanidm | API de administração (usuários, grupos, service accounts, OAuth2 clients) |
| Warpgate | **Terraform provider** + API/SDK OpenAPI (targets, roles, concessões) |
| Guacamole | REST API (conexões, usuários, permissões) |
| OpenBao | API HTTP (policies, SSH CA, DB roles, emissão/revogação) |
| NetBird | API (peers, grupos, políticas de acesso) |

**Operações-chave a expor no Mentors Axis:**
- `provisionar_usuario(tenant, perfil)` → cria em Kanidm + aplica RBAC.
- `conceder_acesso(usuario, target, ttl)` → cria role/target no gateway + policy no OpenBao.
- `revogar_tudo(usuario)` → desabilita em Kanidm; invalida leases no OpenBao (offboarding).
- `sincronizar_tenants()` → reflete o registro de clientes do Mentors Axis nos tenants da plataforma.

Provisionamento por **IaC (Terraform)** onde possível — fonte de verdade versionada, não cliques manuais.

---

## 12. Implantação (Docker Swarm + Traefik)

- **Docker Swarm + Traefik** como base (já padrão IntegrAllTech). Traefik faz o roteamento/TLS na borda.
- **Persistência externa:** Warpgate e Guacamole devem usar **PostgreSQL externo** (não o SQLite default do Warpgate) para HA e auditoria confiável.
- **Componentes:** Kanidm, OpenBao (com storage adequado e *unseal* seguro), Warpgate, `guacd` + webapp Guacamole, NetBird (control plane + peers), ArchGuard/console.
- **HA:** OpenBao em modo HA (storage compatível); Kanidm com replicação; gateways stateless atrás do Traefik onde possível.
- **Footprint:** Warpgate é leve (binário único, ~8 MB RAM). O peso maior está em OpenBao (HA/unseal) e Guacamole (JVM + guacd).
- **Segredos de bootstrap:** raiz do OpenBao, chave da CA, credenciais de admin — guardados fora da plataforma que eles mesmos protegem (evitar dependência circular).

---

## 13. Modelo de ameaças e considerações de segurança

- **Comprometimento do gateway** = alto impacto → hardening, isolamento em DMZ, exposição mínima, patching.
- **OpenBao é o centro de gravidade** → unseal seguro, política de acesso restrita, auditoria de emissão.
- **Dependência circular de segredos** → o bootstrap não pode depender da própria plataforma.
- **Sessão do console (SSRF/token leak)** → manter o padrão ArchGuard (token fora do browser, proxy server-side com validação de path).
- **Caso agêntico** → prompt injection, blast radius, on-behalf-of, HITL, kill-switch (ver §9.4). Agente é **não-confiável por padrão**.
- **Isolamento entre tenants** → um cliente jamais alcança recursos de outro (rede + RBAC).
- **Gravações contêm dado sensível** → cifragem em repouso, controle de acesso às gravações, retenção.

---

## 14. Licenciamento e governança

| Componente | Licença | Governança | Observação |
|---|---|---|---|
| Kanidm | MPL-2.0 | Comunidade/projeto | Copyleft fraco (arquivo); uso como engine é tranquilo |
| Warpgate | Open-source | warp-tech, contratos de suporte | "Sem VC enshittification"; Terraform + SDKs |
| Apache Guacamole | Apache 2.0 | **ASF** | Governança de fundação; baixo risco de rug-pull |
| OpenBao | MPL-2.0 | **Linux Foundation** | Fork do Vault, foge do BSL da HashiCorp |
| NetBird | BSD-3 | Projeto | Permissiva |
| ArchGuard | Proprietário (IntegrAllTech) | Interno | De vocês |
| UseDevKit | MIT | Interno | Plano de config das apps (fora do bastion) |

Nenhum componente central tem licença copyleft forte (AGPL) nem BSL/FSL que atrapalhe extensão e integração com o Mentors Axis. Preferência por governança de fundação (ASF, Linux Foundation) nas peças críticas.

---

## 15. Roadmap faseado

### Fase 1 — Eixo de identidade (alicerce)
- Kanidm como IdP OIDC operado pelo ArchGuard.
- Warpgate e Guacamole autenticando contra o Kanidm.
- Console operador (ArchGuard) para gestão básica de usuários/targets.
- **Entrega:** login único ponta a ponta; dev vê suas conexões.

### Fase 2 — Credenciais efêmeras (o coração)
- OpenBao com SSH CA e DB dinâmico (PostgreSQL).
- Fluxo de offboarding sem rotação, validado com um cliente-piloto.
- **Entrega:** revogar acesso em um clique, com expiração automática.

### Fase 3 — Rede e cobertura de protocolo
- NetBird ligando a plataforma às redes-alvo (piloto: um cliente).
- RDP via Guacamole; validação de Oracle no OpenBao.
- **Entrega:** cobertura SSH/RDP/DB/K8s/Web para o piloto.

### Fase 4 — UnifiedUI e integração Mentors Axis
- Componente React com `guacamole-common-js`.
- Contratos de API/Terraform costurados ao Mentors Axis (onboarding/offboarding automatizados).
- **Entrega:** single pane of glass; provisionamento por IaC.

### Fase 5 — Escala e agêntico (evolução)
- HA (OpenBao, Kanidm, persistência externa).
- OpenSRE como service account, read-only primeiro, HITL para write.
- **Entrega:** plataforma como control plane de acesso agêntico governável.

---

## 16. Decisões em aberto (stubs de ADR)

- **ADR-001 — Oracle via OpenBao.** Validar plugin/engine dinâmico do OpenBao para Oracle (clientes usam Consinco/Oracle). Alternativas: credencial dinâmica nativa vs. proxy via Warpgate (Warpgate cobre MySQL/PostgreSQL, não Oracle). **Pendente.**
- **ADR-002 — step-ca como alternativa/complemento ao OpenBao SSH CA.** Avaliar se step-ca simplifica a CA SSH sem perder o DB dinâmico do OpenBao. **Pendente.**
- **ADR-003 — Persistência do Warpgate.** Confirmar PostgreSQL externo obrigatório para HA/auditoria (não SQLite). **Recomendado, a formalizar.**
- **ADR-004 — Fronteira ArchGuard × Mentors Axis.** Definir o que é console (ArchGuard) e o que é orquestração (Mentors Axis); evitar duplicação de responsabilidade multi-tenant. **Pendente.**
- **ADR-005 — Nome e posicionamento do produto.** AccessLenz? ArchGuard como umbrella? Interno ou produto da família IntegrAllTech? **Pendente.**
- **ADR-006 — Estratégia de frontend.** UI stock do Guacamole (rebrand) no PoC → UnifiedUI React (guacamole-common-js) em produção. **Recomendado, a formalizar.**

---

## 17. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| ArchGuard e UseDevKit são scaffolds iniciais (poucos commits, roadmap aberto) | Tratar como projeto interno a amadurecer; engines por baixo (Kanidm, PostgreSQL, AES-GCM) são maduros; não plugar como "produto pronto" |
| Oracle sem engine dinâmico validado | ADR-001; fallback com credencial gerenciada e TTL manual até validar |
| Esforço da UnifiedUI subestimado | Faseamento: rebrand no PoC, React depois |
| OpenBao como ponto único crítico | HA, unseal seguro, bootstrap externo, auditoria |
| Agente autônomo com acesso a produção de cliente | Read-only primeiro, HITL, local-first, consentimento do cliente |
| Vazamento entre tenants | Segmentação de rede + RBAC estrito + testes de isolamento |

---

*Documento vivo. Próximo passo recomendado: detalhar a Fase 1 (Kanidm como IdP + Warpgate/Guacamole confiando nele) e o fluxo ArchGuard/Kanidm ↔ OpenBao do certificado efêmero.*
