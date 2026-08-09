# Inventário de legado de identidade

Status: `superseded` — não faz parte do runtime atual do ArchGate.

O runtime suportado é o ArchGate DevOps (Compose/RustGuac/OpenBao/Warpgate)
integrado ao ArchGuard SaaS em `https://app.archguard.com.br`. O diretório
`deploy/` deste repositório contém material histórico de uma topologia anterior
e não deve ser usado para provisionar a VPS.

## Itens ainda a retirar ou arquivar

Os seguintes grupos ainda contêm referências ao runtime de identidade antigo e
devem ser removidos em uma mudança dedicada, após confirmar que nenhum pipeline
os chama:

- `deploy/versions.env` e os manifests de stack antigos;
- `deploy/agentic/bootstrap-opensre-sa.sh`;
- `deploy/archguard/`;
- `deploy/validation/smoke-archguard-cutover.sh`;
- `deploy/validation/w0-validate.sh` e `health-monitor.sh` antigos;
- OpenSpecs e documentos que descrevem o antigo host local como runtime.

Até essa remoção, esses arquivos são somente evidência histórica e não devem
ser copiados para a VPS. O deploy oficial continua sendo feito a partir de
`archgate-devops/scripts/sync-to-vps.sh`.
