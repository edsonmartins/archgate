# Política — Inferência local (W5-AG08)

| Campo | Valor |
|-------|--------|
| ADR | [ADR-012](../../adr/ADR-012-acesso-agentico-opensre.md) |
| Spec | agentic-access / Inferência Local |

## Regra

**Se** o agente processa dado de produção de cliente (logs, PII, configs, dumps):

→ a inferência **SHALL** rodar em infraestrutura IntegrAllTech (**local-first**):

- GPU lab (ex. RTX) com vLLM / runtime aprovado, **ou**
- Mac Mini / host on-prem dedicado, **ou**
- VPC privada sem egress para provedores LLM públicos

**Proibido:** enviar conteúdo de cliente a APIs SaaS (OpenAI/Anthropic/etc.) sem DPA + classificação + aprovação segurança.

## Classificação de entrada

| Entrada | SaaS LLM? | Local? |
|---------|-----------|--------|
| Runbook genérico / docs públicos | ok com cuidado | preferível |
| Logs/alertas de cliente | **não** | **obrigatório** |
| Snippets sem PII anonimizados | caso a caso | preferível |
| Secrets / tokens | **nunca** a LLM | nunca |

## Controles

1. Egress firewall do host de inferência (deny default a APIs LLM).  
2. Audit: modelo, host, correlation_id da sessão agêntica.  
3. OpenSRE runtime configura `INFERENCE_ENDPOINT=http://local-vllm:8000` (não cloud).  
4. Feature flag: `AGENT_ALLOW_CLOUD_LLM=false` default.

## Exceções

Só com:

- Consentimento escrito do cliente,  
- Classificação do dado,  
- Aprovação segurança IntegrAllTech,  
- Registro no ticket do incidente.
