# OpenBao HA (W5-HA01)

Lab hoje: **single-node file storage** + unseal systemd.  
Produção alvo: **Raft** + **auto-unseal**.

## Arquivos

| File | Uso |
|------|-----|
| `raft.hcl.example` | listener + storage raft + api_addr/cluster_addr |
| `auto-unseal-transit.example.hcl` | seal "transit" (ou trocar por awskms/azurekeyvault) |
| `swarm-stack.ha.example.yml` | 3 tasks (sketch Swarm) |

## Bootstrap resumido (Raft)

1. Subir nó 1 com `storage "raft"` e `bootstrap_expect = 3`.  
2. `bao operator init` **uma vez** → guardar recovery keys offline.  
3. Configurar auto-unseal **antes** de reinícios de rotina.  
4. Join nós 2–3: `bao operator raft join http://openbao-1:8200`.  
5. Verificar: `bao operator raft list-peers`.

## Auto-unseal

Preferências IntegrAllTech (ordem):

1. **Transit** em OpenBao “root of trust” isolado (rede admin).  
2. KMS interno / HSM.  
3. Cloud KMS só se política permitir.

**Não** deixar unseal key no env do console em produção (`ARCHGATE_LAB=0`).

## Validação

```bash
bao status                 # Sealed false, HA enabled
bao operator raft list-peers
# kill 1 container → emissão de lease ainda ok
```

Failover: `documentos/runbooks/ha-failover-tests.md` F1.
