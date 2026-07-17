# Matriz de protocolos por site (W2-PROTO01)

> Preencher por site após inventário. Operador **sempre** via bastion (Warpgate / Guac).

## Legenda

| Status | Significado |
|--------|-------------|
| `lab` | Validado só em overlay lab |
| `ok` | E2E com peer real |
| `n/a` | Não aplicável ao site |
| `pend` | Cliente tem, path ArchGate ainda não |
| `block` | Dependência (ex. host Windows) |

## Matriz mestre

| Site | SSH WG | PG WG | MySQL WG | RDP Guac | SSH Guac | K8s WG | HTTP WG | Notas |
|------|:------:|:-----:|:--------:|:--------:|:--------:|:------:|:-------:|-------|
| Rio Quality **lab** | lab | lab | n/a | n/a | lab | n/a | n/a | `rio-lab-*` |
| Rio Quality **prod** | pend | pend | n/a | pend? | pend | n/a | pend? | peer W0-B |
| Grupo Marra **lab** | lab | lab | n/a | n/a | lab* | n/a | n/a | *marra browser se provisionado |
| Grupo Marra **prod** | pend | pend | n/a | pend | pend | n/a | pend | stack a_confirmar |
| Piloto connector lab | lab | n/a | n/a | n/a | n/a | n/a | n/a | WG path |
| aj_rorato (Axis) | pend | pend | pend | pend | pend | pend | pend | SoT a_confirmar |
| credicoamo | pend | pend | pend | pend | pend | pend | pend | SoT a_confirmar |
| fiomar | pend | pend | pend | pend | pend | pend | pend | SoT a_confirmar |
| mentors_* | pend | pend | pend | pend | pend | pend | pend | SoT a_confirmar |
| taf | pend | pend | pend | pend | pend | pend | pend | SoT a_confirmar |

\* Atualizar com `docker`/console SoT quando stack real for confirmada.

## Por protocolo — caminho padrão

| Protocolo | Engine | Porta bastion (lab) | Snippet |
|-----------|--------|---------------------|---------|
| SSH | Warpgate | `:2222` | `snippets/ssh-warpgate.example` |
| PostgreSQL | Warpgate | `:55432` ssl | `snippets/dbeaver-warpgate-postgres.example` |
| MySQL | Warpgate | conforme publish | targets MySql |
| SSH browser | Guacamole | HTTPS guac | portão oauth2-proxy |
| RDP | Guacamole | HTTPS guac | host Windows necessário |
| K8s | Warpgate | HTTPS/API | target kind K8s (quando cadastrado) |
| HTTP(S) interno | Warpgate | HTTPS wg | target Http |

## Critério W2-PROTO “mínimo 1 site prod”

Para **um** site real: SSH **ou** PG via Warpgate **ok** + isolamento tenant.  
RDP/K8s = extensão quando o site exigir.
