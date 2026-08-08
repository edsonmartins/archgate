# Tasks — Add Agentic Access & HA (Fase 5)

## 1. Alta disponibilidade
- [ ] 1.1 OpenBao em modo HA (storage compatível, auto-unseal seguro)
- [ ] 1.2 archguard com replicação
- [ ] 1.3 Persistência externa confirmada (Warpgate/Guacamole em PostgreSQL externo)
- [ ] 1.4 Gateways stateless atrás do Traefik onde possível
- [ ] 1.5 Testes de failover por componente

## 2. Identidade do agente
- [ ] 2.1 Criar service account do OpenSRE no archguard com escopo mínimo
- [ ] 2.2 Amarrar toda ação do agente à service account + humano autorizador (on-behalf-of)

## 3. Política no gateway (não no modelo)
- [ ] 3.1 Allow-list de comandos para o agente
- [ ] 3.2 Escopo por host/incidente
- [ ] 3.3 TTL curtíssimo e rate limit para conter blast radius
- [ ] 3.4 JIT: credencial efêmera via OpenBao com escopo por incidente

## 4. HITL e read-only
- [ ] 4.1 Enforcement read-only por padrão (diagnóstico automático)
- [ ] 4.2 Gate HITL para qualquer ação mutante/destrutiva (fluxo de aprovação do Warpgate)
- [ ] 4.3 Roteamento da aprovação a um humano responsável em tempo real

## 5. Kill-switch e inferência local
- [ ] 5.1 Validar: revogar service account no archguard interrompe o agente e expira credenciais
- [ ] 5.2 Inferência local (vLLM RTX 3060 / Mac Mini M4) — sem enviar dado de produção a APIs de terceiros
- [ ] 5.3 Consentimento do cliente para operação agêntica em seus ambientes

## 6. Validação
- [ ] 6.1 Agente diagnostica (read-only) sem qualquer write não aprovado
- [ ] 6.2 Ação mutante bloqueada até aprovação humana
- [ ] 6.3 Kill-switch comprovado; auditoria mostra cadeia principal→humano→ação
- [ ] 6.4 Teste de prompt injection: conteúdo malicioso em log não escala privilégio
