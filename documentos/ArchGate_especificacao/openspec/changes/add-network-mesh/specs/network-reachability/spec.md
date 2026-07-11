# Spec Delta — network-reachability

## ADDED Requirements

### Requirement: Malha de Rede Central
O sistema SHALL prover alcançabilidade às redes dos clientes por meio de uma malha WireGuard central (NetBird), com peers nas redes-alvo e junto aos gateways.

#### Scenario: Gateway alcança alvo pela malha
- **WHEN** um gateway precisa conectar a um alvo na rede de um cliente
- **THEN** a conexão trafega pela malha WireGuard
- **AND** o desenvolvedor não recebe acesso direto à rede do cliente

### Requirement: Segmentação por Tenant
A malha SHALL isolar o alcance por tenant, de forma que peers de um cliente não alcancem recursos de outro.

#### Scenario: Isolamento entre clientes
- **WHEN** um recurso do tenant A tenta alcançar um recurso do tenant B pela malha
- **THEN** a política da malha nega o tráfego

### Requirement: Integração com Cloudflare Tunnel
Onde houver Cloudflare Tunnel, o sistema SHALL integrá-lo como via de borda complementar, sem exigir portas de entrada abertas.

#### Scenario: Coexistência malha e Tunnel
- **WHEN** um cliente já usa Cloudflare Tunnel (ex.: Rio Quality)
- **THEN** o acesso funciona pela via de borda existente sem rota conflitante com a malha

### Requirement: Cobertura de Protocolo Ponta a Ponta
O sistema SHALL suportar SSH, RDP, banco (PostgreSQL e Oracle), Kubernetes e painéis web contra redes reais de clientes.

#### Scenario: RDP a host Windows real
- **WHEN** um desenvolvedor abre um desktop Windows de cliente via Guacamole
- **THEN** a sessão é estabelecida pela malha e gravada

#### Scenario: Acesso Oracle conforme decisão
- **WHEN** um desenvolvedor solicita acesso a um banco Oracle de cliente
- **THEN** o acesso ocorre pelo mecanismo definido no ADR-001, sem expor credencial de longa vida ao desenvolvedor
