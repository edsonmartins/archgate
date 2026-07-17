# Tasks — Add Oracle Credential Proxy

## 1. Proxy Java (Spring Boot 3.x / Java 21)
- [x] 1.1 Esqueleto do serviço com endpoints para as operações de plugin (create/update/delete user, rotate root) — `services/oracle-proxy` mock 2026-07-17
- [ ] 1.2 Integrar driver JDBC thin (ojdbc) — Java puro, sem Instant Client
- [ ] 1.3 Configurar conexão Oracle por descritor/TNS (validar contra ambiente Consinco/PDB)
- [ ] 1.4 Executar creation statements: CREATE USER + GRANT com senha e expiração
- [ ] 1.5 Executar revocation: DROP USER (CASCADE) na revogação de lease
- [ ] 1.6 Executar rotate/expiração: ALTER USER (senha) e/ou ACCOUNT LOCK
- [x] 1.7 Tratar limite de tamanho de identificador Oracle nos nomes de usuário gerados — validação 30 chars no mock

## 2. Plugin Go fino (interface dbplugin v5)
- [ ] 2.1 Implementar Initialize/NewUser/UpdateUser/DeleteUser/Type/Close encaminhando ao proxy — scaffold HTTP CLI only
- [ ] 2.2 Implementar RotateRootCredentials encaminhando ao proxy
- [x] 2.3 Empacotar binário sem dependências Oracle — `go run` helper sem Oracle libs
- [ ] 2.4 Registrar no catálogo de plugins do OpenBao (sys/plugins/catalog)

## 3. Segurança do canal e credenciais
- [ ] 3.1 mTLS entre plugin Go e proxy Java
- [ ] 3.2 Usuário administrativo Oracle dedicado com privilégio mínimo (CREATE/ALTER/DROP USER, GRANT) — não DBA
- [ ] 3.3 Injeção segura do segredo administrativo (sem hardcode)
- [ ] 3.4 Rotação da credencial administrativa (rotate-root) validada

## 4. Configuração no OpenBao
- [ ] 4.1 Configurar a conexão de banco apontando ao plugin/plugin-name
- [ ] 4.2 Definir role dinâmico Oracle: creation_statements, revocation_statements, TTL/max_ttl
- [ ] 4.3 Ajustar username_template ao limite de identificador da versão Oracle-alvo
- [ ] 4.4 Amarrar emissão à identidade Kanidm (rastreabilidade)

## 5. Validação
- [ ] 5.1 Emitir credencial Oracle dinâmica com TTL e conectar ao banco de teste
- [ ] 5.2 Expiração automática: usuário removido/bloqueado ao fim do lease
- [ ] 5.3 Revogação imediata: revogar lease dropa o usuário no Oracle
- [ ] 5.4 TNS/failover exercitado (se aplicável ao ambiente Rio Quality)
- [ ] 5.5 Reconciliação de usuários órfãos em caso de falha de revogação
- [ ] 5.6 Nenhuma biblioteca nativa Oracle presente na imagem do OpenBao
