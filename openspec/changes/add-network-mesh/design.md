# Design — Add Network Mesh (Fase 3)

## Contexto
Fecha a alcançabilidade de rede e a cobertura de protocolo. Sem esta fase, identidade e credenciais efêmeras não têm como chegar aos alvos reais dos clientes de forma unificada.

## Decisões técnicas

### D1 — Malha WireGuard central (NetBird) no lugar de VPNs avulsas
Uma malha única, com peers nas redes dos clientes e junto aos gateways, substitui o emaranhado atual. Controle de acesso central; a malha é **infraestrutura** e não é exposta ao dev.

### D2 — Segmentação por tenant é obrigatória
O alcance de um cliente não pode vazar para outro. Políticas da malha isolam peers por tenant. Testado explicitamente (5.2).

### D3 — Cloudflare Tunnel coexiste, não é substituído
Onde já existe (Rio Quality), o Tunnel permanece como via de borda (saída 7844, sem abrir portas de entrada). Integra-se à malha em vez de competir.

### D4 — Oracle: decisão nesta fase (ADR-001)
Warpgate cobre MySQL/PostgreSQL nativamente, não Oracle. Opções a decidir no ADR-001:
- credencial dinâmica via engine Oracle do OpenBao (se validado), ou
- credencial gerenciada com TTL manual como interino, ou
- proxy específico.
Como os clientes principais são Consinco/Oracle, esta decisão é bloqueadora da fase.

## Riscos e mitigações
- **Vazamento entre tenants** → segmentação + teste de isolamento (D2, 5.2).
- **Oracle sem engine dinâmico** → fallback gerenciado com TTL até validar (ADR-001).
- **Rota conflitante malha × Tunnel** → validação de coexistência (2.2).
- **Peer em rede de cliente** exige acordo/onboarding com o cliente → tratar no processo, não só técnico.

## Fora de escopo
UnifiedUI (Fase 4), agêntico e HA (Fase 5).
