# ADR-001 — Acesso a banco Oracle via proxy Java para o OpenBao

- **Status:** Aceito
- **Data:** julho de 2026
- **Contexto de fase:** bloqueador da Fase 3 (`add-network-mesh`)
- **Relacionado:** `ephemeral-credentials` (Fase 2/3), pacote `add-oracle-credential-proxy`

## Contexto

A plataforma emite credenciais dinâmicas de banco via OpenBao (Fase 2). Para PostgreSQL isso é nativo. Para **Oracle** — banco dos clientes Consinco, incluindo Rio Quality — há duas lacunas simultâneas:

1. O **Warpgate** não faz proxy nativo de Oracle (cobre SSH/HTTPS/K8s/MySQL/PostgreSQL).
2. O **OpenBao** não inclui driver Oracle no Database Secrets Engine. O suporte a Oracle na linhagem Vault é limitado porque o plugin oficial depende de bibliotecas cliente Oracle nativas, incompatíveis com a imagem Alpine padrão.

Sem uma decisão de caminho, a célula "acesso a banco Oracle" da matriz de protocolo fica sem implementação, travando a conclusão da Fase 3 para clientes Oracle.

## Decisão

Implementar o acesso a credencial dinâmica Oracle por meio de um **proxy Java** que atende à interface de plugin de banco (custom database plugin) do OpenBao, usando o **driver JDBC thin da Oracle (ojdbc)**.

Arquitetura:

```
OpenBao ──(dbplugin v5, Go)──> Plugin Go fino ──HTTP/gRPC (mTLS)──> Proxy Java (Spring Boot) ──JDBC thin──> Oracle
```

- Um **plugin Go fino** implementa a interface `dbplugin` v5 do OpenBao (NewUser, UpdateUser, DeleteUser, RotateRoot) e apenas encaminha as operações.
- Um **proxy Java (Spring Boot 3.x / Java 21)** recebe as operações e as executa no Oracle via **JDBC thin (ojdbc)**, sem bibliotecas nativas.
- As bibliotecas/driver Oracle vivem **no proxy**, fora da imagem do OpenBao.

## Opções consideradas

| Opção | Prós | Contras | Veredito |
|---|---|---|---|
| Driver Go puro (`go-ora`) | Simples, sem libs nativas | **Sem TNS aliasing** → sem failover multi-instância | Rejeitada se houver TNS/failover |
| `godror` + Instant Client | Recursos completos | Exige trocar imagem base, empacotar libs nativas, licença e manutenção | Rejeitada (ônus na imagem do OpenBao) |
| **Proxy Java + ojdbc thin** | Java puro (sem libs nativas), **suporta TNS/failover**, joga na força da equipe | Uma peça a mais para construir/manter | **Escolhida** |
| Interino gerenciado (TTL curto) | Destrava rápido | Não é emissão dinâmica plena | Ponte opcional, não solução |

## Justificativa

- **ojdbc thin é Java puro** — não requer Oracle Instant Client, então nada de bibliotecas nativas em imagem alguma.
- **Suporta TNS e descritores de conexão** — resolve a limitação que elimina o `go-ora` (failover multi-instância).
- **Alinha à stack da IntegrAllTech** — Spring Boot 3.x + Java 21, e Oracle JDBC já em uso no Gestor-RQ/Consinco. Domínio existente, retrabalho mínimo.
- **Mantém o OpenBao limpo** — o plugin Go é fino e sem dependências Oracle; o risco/licença fica isolado no proxy.

## Consequências

**Positivas:** cobertura Oracle com credencial dinâmica e TTL; sem libs nativas na imagem do OpenBao; TNS/failover suportado; reaproveita competência Java.

**Negativas / custos:** um serviço a mais para construir, implantar e manter; canal OpenBao↔proxy precisa de mTLS; o proxy detém a credencial administrativa Oracle (usuário que cria/dropa contas) — superfície sensível.

## Riscos e mitigações

- **Limite de tamanho de identificador Oracle** (usuários curtos em versões antigas) → ajustar `username_template` do OpenBao ao limite da versão Oracle-alvo.
- **Credencial administrativa no proxy** → usuário Oracle dedicado com privilégio mínimo (CREATE/ALTER/DROP USER, GRANT), não DBA pleno; segredo injetado com segurança.
- **PDB/CDB (multitenant Oracle)** → conectar ao serviço/PDB correto; validar com o ambiente Consinco.
- **Usuários órfãos** se a revogação falhar → reconciliação/limpeza periódica.
- **Postura de acesso** → decisão de acesso do dev (injeção vs. malha + credencial efêmera) tratada na spec da Fase 3; este ADR cobre a **emissão**, não o transporte.

## Pergunta de decisão que este ADR fecha

> O Oracle do Rio Quality exige TNS aliasing / failover multi-instância?

Independentemente da resposta, o proxy Java + ojdbc thin atende (com ou sem TNS), o que torna a escolha robusta a ambos os cenários — motivo adicional para preferi-la ao `go-ora`.

## Referências

- Discussão de suporte Oracle no OpenBao (issue #2237) e docs de custom database plugin.
- Documento de arquitetura, §16 (ADR-001).
- Pacote de implementação: `openspec/changes/add-oracle-credential-proxy/`.
