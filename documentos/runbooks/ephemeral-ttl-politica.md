# Política de TTL — credenciais efêmeras (W1-EPH02)

Fonte de configuração: `deploy/openbao/bootstrap-engines.sh` e `bootstrap-kanidm-auth.sh`.

## Valores lab atuais (referência)

| Recurso | default / ttl | max | Notas |
|---------|---------------|-----|--------|
| SSH CA role `lab-user` | **15m** | **30m** | cert assinado no smoke |
| DB role `lab-readonly` | **30m** | **2h** | broker Warpgate renova via timer |
| JWT role `archgate-operator` | **30m** | **2h** | token OpenBao pós-Kanidm |
| JWT role admin (se houver) | **1h** | **4h** | bootstrap-kanidm-auth |
| Broker timer | ~20 min | — | `archgate-broker-db.timer` |

## Política alvo produção

| Caso de uso | TTL sugerido | Max |
|-------------|--------------|-----|
| Sessão operador DB (read) | 30m–1h | 2h |
| Sessão operador DB (write, se existir) | 15–30m | 1h |
| Cert SSH (quando nativo) | 15–30m | 1h |
| Token OpenBao app/console | 30m–1h | 4h |
| Break-glass root | **não** usar no app; ops only | — |

## Regras

1. **Menor TTL viável** para o fluxo do operador (DBeaver/ssh sem reauth a cada 2 min).  
2. Broker deve renovar **antes** do lease expirar (timer &lt; default_ttl).  
3. Offboarding IdP **não** depende de TTL — revoga identidade; leases expiram naturalmente.  
4. Alterar TTLs: editar bootstrap OpenBao + re-aplicar roles + smoke.

## Checklist

- [x] TTLs lab documentados  
- [ ] Revisar números com segurança IntegrAllTech antes de 1º cliente prod  
- [ ] Ajustar broker timer se default_ttl mudar  
