# Spec Delta — operator-client-access

Padrão de acesso do **cliente operador** (notebook) e da **configuração de site** do cliente final. Alinhado ao ADR-008.

## ADDED Requirements

### Requirement: Acesso privilegiado exclusivamente via bastion

O sistema SHALL exigir que o acesso privilegiado a alvos de cliente ocorra através dos gateways ArchGate (Warpgate e/ou Guacamole / UnifiedUI futura), e SHALL NOT documentar nem operar como fluxo padrão o acesso SSH/RDP/SQL direto do notebook do operador ao IP do alvo com credencial de alvo no endpoint.

#### Scenario: Fluxo padrão do operador
- **WHEN** um operador precisa de acesso privilegiado a um alvo de cliente
- **THEN** a sessão é estabelecida via bastion ArchGate
- **AND** a credencial do alvo permanece no gateway (ou cofre/gateway), não no notebook do operador

#### Scenario: Anti-padrão rejeitado como padrão
- **WHEN** a documentação oficial de acesso é consultada
- **THEN** o uso de VPN do cliente no notebook combinado com SSH/RDP/SQL direto ao alvo é descrito como proibido ou apenas como exceção controlada

---

### Requirement: Cliente operador multi-OS

O padrão de acesso do operador SHALL ser suportado em **Linux**, **macOS** e **Windows** no notebook, com o mesmo contrato de endpoints (hosts, portas, forma de autenticação no bastion), sem exigir aplicativo desktop proprietário ArchGate nas fases 1–3.

#### Scenario: SSH via Warpgate nos três SO
- **WHEN** um operador em Linux, macOS ou Windows usa OpenSSH contra o endpoint SSH do Warpgate com a forma `usuario:target@host`
- **THEN** a sessão SSH privilegiada é estabelecida conforme RBAC do target
- **AND** o comando documentado é semanticamente o mesmo nos três sistemas operacionais

#### Scenario: Sessão gráfica no browser
- **WHEN** um operador em Linux, macOS ou Windows abre o Guacamole (ou UnifiedUI futura) no browser suportado
- **THEN** consegue iniciar conexão RDP/VNC/SSH web autorizada, sem cliente RDP nativo obrigatório

#### Scenario: Proxy de banco multiplataforma
- **WHEN** um operador usa cliente SQL oficialmente suportado (ex.: DBeaver) apontando ao proxy de banco do Warpgate
- **THEN** o acesso ao banco do cliente ocorre sem expor a senha do banco no fluxo documentado do operador

---

### Requirement: Modelo híbrido browser e desktop

O sistema SHALL suportar dois modos de cliente operador, ambos terminando no bastion:

| Parte | Modo | Uso primário |
|-------|------|--------------|
| A | Browser (clientless) | RDP, VNC, SSH web, console de identidade |
| B | Desktop via bastion | SSH (OpenSSH), PostgreSQL/MySQL (cliente SQL) |

#### Scenario: RDP primário no browser
- **WHEN** um operador precisa de RDP a um desktop Windows de cliente
- **THEN** o caminho documentado como primário é a sessão no browser via Guacamole (ou UnifiedUI)
- **AND** cliente RDP nativo, se mencionado, é opcional/avançado

#### Scenario: SSH e DB primários no desktop via bastion
- **WHEN** um operador precisa de SSH interativo ou acesso a PostgreSQL/MySQL
- **THEN** o caminho documentado como primário usa OpenSSH e/ou cliente SQL contra o Warpgate
- **AND** SSH web permanece disponível como opção browser

---

### Requirement: Servidor alvo tipicamente Linux

A documentação e o provisionamento padrão de targets SHALL assumir alvos **Linux** para SSH e bancos, e SHALL tratar RDP Windows como caso quando o serviço do cliente exigir desktop Windows — sem confundir SO do alvo com SO do notebook do operador.

#### Scenario: Target SSH Linux
- **WHEN** um target SSH de cliente é cadastrado no fluxo padrão
- **THEN** o host alvo é tratado como endpoint Linux alcançável pelo path de conectividade do site

#### Scenario: Target RDP Windows
- **WHEN** o cliente exige acesso a workstation/servidor Windows
- **THEN** o target é cadastrado no Guacamole (RDP) com sessão browser como primário

---

### Requirement: Conectividade do site na configuração do cliente

A configuração de acesso de cada cliente (site) SHALL incluir um bloco de **conectividade** que descreve como o bastion alcança a rede do cliente, distinto da identidade e dos targets.

#### Scenario: Ficha de cliente completa
- **WHEN** um cliente é onboarding na plataforma
- **THEN** a ficha registra no mínimo: tenant/identidade, tipo de conectividade, lista de targets, roles autorizadas e indicação de onde residem as credenciais de alvo (gateway)

#### Scenario: Tipos de conectividade
- **WHEN** a conectividade é classificada
- **THEN** o tipo é um de: `connector_peer`, `tunnel_agent`, ou `vpn_user_exception`
- **AND** `connector_peer` e `tunnel_agent` são preferidos em relação a `vpn_user_exception`

---

### Requirement: Um path de rede, N operadores

O desenho preferido SHALL permitir que **uma** conta ou túnel VPN/conectividade institucional do cliente sirva de path de rede para **múltiplos** operadores ArchGate autenticados individualmente (SSO/identidade), sem compartilhar a credencial VPN do cliente nos notebooks da equipe.

#### Scenario: Múltiplos operadores, um connector
- **WHEN** dois operadores autorizados do mesmo tenant abrem sessões concorrentes a targets do cliente
- **THEN** ambos autenticam com suas identidades ArchGate
- **AND** o tráfego até a rede do cliente usa o path de conectividade institucional do site (não uma VPN de usuário distinta por operador, no modelo preferido)

#### Scenario: Proibição de conta VPN compartilhada no endpoint
- **WHEN** a política de acesso é aplicada
- **THEN** compartilhar uma única credencial de VPN de usuário do cliente em múltiplos notebooks da equipe NÃO é o modelo preferido nem o documentado como padrão

---

### Requirement: Exceção VPN de usuário controlada

Quando o contrato do cliente exigir VPN de usuário no notebook e proibir connector, o sistema (processo) SHALL registrar a exceção `vpn_user_exception` com inventário de hosts, MFA na VPN quando disponível, e plano de migração — sem tratar a exceção como default.

#### Scenario: Exceção documentada
- **WHEN** um cliente só permite VPN de usuário
- **THEN** a ficha do cliente marca `vpn_user_exception`
- **AND** a lista de hosts/portas permitidos está inventariada
- **AND** o offboarding inclui revogação da VPN e da identidade ArchGate

---

### Requirement: Clientes oficiais suportados

A plataforma SHALL publicar uma lista curta de clientes oficiais no notebook do operador para o fluxo padrão.

#### Scenario: Lista mínima
- **WHEN** um operador configura a estação de trabalho
- **THEN** a documentação lista browser suportado, OpenSSH e um cliente SQL multiplataforma (ex.: DBeaver) como oficiais
- **AND** não exige agente ArchGate instalado para SSH/DB/RDP-browser nas fases 1–3

---

### Requirement: Runbooks oficiais

A plataforma SHALL manter runbooks versionados para (1) operador multi-OS e (2) onboarding de site/cliente, referenciando o ADR-008.

#### Scenario: Runbook do operador
- **WHEN** um operador novo entra no time
- **THEN** existe runbook com URLs/endpoints, exemplos SSH/SQL/browser, checklist por SO e anti-padrões

#### Scenario: Runbook de onboarding de site
- **WHEN** a plataforma habilita um novo cliente
- **THEN** existe runbook com checklist de identidade, conectividade, targets, credenciais e autorização

---

### Requirement: Matriz de aceite multi-OS

A validação do padrão SHALL incluir evidência de acesso a partir de estações operador Linux, macOS e Windows (no mínimo SSH via Warpgate em lab; DB e RDP web quando provisionados).

#### Scenario: Aceite SSH multi-OS
- **WHEN** a capability é considerada pronta para o lab de referência
- **THEN** há evidência de sessão SSH bem-sucedida via Warpgate a partir de Linux, macOS e Windows do operador (ou justificativa explícita de SO indisponível no lab com reteste agendado)

---

### Requirement: Independência parcial do SSO Guacamole

Personas que usam apenas Parte B (SSH/DB via Warpgate) SHALL poder operar o padrão sem depender da resolução da task de OIDC nativo do Guacamole (4.2 / ADR-007).

#### Scenario: Operador só Warpgate
- **WHEN** um operador autorizado usa somente SSH e proxy de banco via Warpgate com SSO archguard
- **THEN** o padrão operator-client-access é satisfeito para essa persona
- **AND** a limitação de login local do Guacamole NÃO bloqueia essa persona

#### Scenario: Persona RDP-browser
- **WHEN** um operador depende de RDP no browser
- **THEN** usa Guacamole conforme estado atual (incluindo limitação SSO se ADR-007 ainda aplicável)
- **AND** a remediação de SSO Guacamole permanece rastreada em ADR-007 / identity-axis 4.2, não como pré-requisito de toda a capability

---

### Requirement: Evolução UnifiedUI preserva o padrão

A UnifiedUI (Fase 4) SHALL preservar o modelo bastion-first e multi-OS, unificando o catálogo de conexões e podendo embutir Parte A e deep-link/instruções para Parte B — sem reintroduzir acesso direto ao alvo como padrão.

#### Scenario: Catálogo unificado futuro
- **WHEN** a UnifiedUI lista conexões autorizadas
- **THEN** iniciar SSH/RDP/DB a partir do catálogo ainda termina no bastion/engines
- **AND** o operador em qualquer SO suportado não precisa de path privilegiado direto à rede do cliente
