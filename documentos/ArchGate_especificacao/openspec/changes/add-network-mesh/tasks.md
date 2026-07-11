# Tasks — Add Network Mesh (Fase 3)

## 1. NetBird — malha
- [ ] 1.1 Subir NetBird control plane (self-hosted)
- [ ] 1.2 Instalar peer na rede de um cliente-piloto
- [ ] 1.3 Instalar peer junto aos gateways (Warpgate/Guacamole)
- [ ] 1.4 Configurar segmentação por tenant (alcance de um cliente não vaza para outro)
- [ ] 1.5 Definir políticas de acesso da malha (quais peers falam com quais)

## 2. Integração Cloudflare Tunnel (Rio Quality)
- [ ] 2.1 Mapear o Tunnel existente como via de borda complementar
- [ ] 2.2 Validar coexistência malha + Tunnel sem rota conflitante

## 3. Alcance via malha
- [ ] 3.1 Validar: gateway alcança alvo do cliente-piloto através da malha
- [ ] 3.2 Confirmar: dev nunca recebe acesso direto à rede do cliente

## 4. Cobertura de protocolo
- [ ] 4.1 RDP ponta a ponta: dev abre desktop Windows real de cliente via Guacamole
- [ ] 4.2 Kubernetes via Warpgate contra cluster de cliente
- [ ] 4.3 **ADR-001 (Oracle):** decidir engine dinâmico OpenBao vs. alternativa
- [ ] 4.4 Implementar acesso Oracle conforme decisão do ADR-001

## 5. Validação de ponta a ponta
- [ ] 5.1 Matriz SSH/RDP/DB/K8s/Web funcional para o cliente-piloto
- [ ] 5.2 Isolamento entre tenants comprovado por teste
- [ ] 5.3 Sessões gravadas independentemente do protocolo
