# Tasks — Add Ephemeral Credentials (Fase 2)

## 1. OpenBao — base
- [ ] 1.1 Subir OpenBao em modo HA com storage compatível
- [ ] 1.2 Definir estratégia de unseal (auto-unseal seguro vs. manual) e guarda das chaves fora da plataforma
- [ ] 1.3 Habilitar auditoria de emissão/revogação
- [ ] 1.4 Definir policies de acesso mínimas (quem pode pedir o quê)

## 2. SSH Secrets Engine (CA)
- [ ] 2.1 Habilitar o SSH secrets engine e gerar a CA
- [ ] 2.2 Configurar roles de assinatura (principais, extensões, TTL 5–15 min)
- [ ] 2.3 Distribuir a chave pública da CA aos alvos SSH (trusted CA)
- [ ] 2.4 Validar assinatura de certificado e login no alvo com certificado efêmero

## 3. Database Secrets Engine (PostgreSQL)
- [ ] 3.1 Habilitar o database secrets engine
- [ ] 3.2 Configurar conexão administrativa ao PostgreSQL-alvo
- [ ] 3.3 Definir roles dinâmicos (permissões mínimas, TTL 15–60 min)
- [ ] 3.4 Validar criação e revogação automática de credencial ao fim do lease

## 4. Integração com Warpgate
- [ ] 4.1 Configurar Warpgate para solicitar certificado SSH efêmero ao OpenBao no fluxo de conexão
- [ ] 4.2 Remover chaves/senhas de longa vida dos targets no Warpgate
- [ ] 4.3 Configurar acesso a banco via credencial dinâmica do OpenBao
- [ ] 4.4 Validar: dev conecta e o alvo aceita apenas certificado assinado pela CA

## 5. Políticas e revogação
- [ ] 5.1 Calibrar TTLs por tipo (SSH, DB) conforme a tabela de políticas
- [ ] 5.2 Validar revogação de leases (kill imediato) e expiração automática
- [ ] 5.3 Amarrar emissão à identidade Kanidm (rastreabilidade principal → credencial)

## 6. Validação de ponta a ponta
- [ ] 6.1 Nenhuma credencial de longa vida reside no Warpgate após a migração
- [ ] 6.2 Offboarding: identidade desabilitada → OpenBao não emite → o que existia expira sozinho
- [ ] 6.3 Auditoria correlaciona: quem pediu, para qual alvo, qual TTL, quando expirou
