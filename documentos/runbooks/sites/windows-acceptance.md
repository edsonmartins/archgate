# Aceite Windows (task 2.5) — procedimento e waiver

## Status

| Item | Estado | Data |
|------|--------|------|
| Procedimento documentado | **Sim** — [windows-openssh-warpgate.example](../snippets/windows-openssh-warpgate.example) | 2026-07-10 |
| Smoke automatizado em host Windows nativo | **Pendente** | — |
| Waiver lab | **Ativo** até primeiro notebook Windows do time executar o checklist | 2026-07-10 |

## Por que waiver é aceitável no lab

- OpenSSH no Windows usa o **mesmo** protocolo/comando que Linux/macOS (`user:target@host` porta 2222).
- Postgres via DBeaver no Windows usa os **mesmos** host/porta/`sslmode=require` já validados em Linux e macOS.
- Risco residual: UI de instalação do Optional Feature OpenSSH e path do `ssh.exe` — coberto pelo snippet.

## Checklist (operador Windows — fechar 2.5)

Execute e anexe evidência (screenshot ou log) em `smoke-evidence-*.md`:

1. [ ] `ssh -V` mostra OpenSSH_for_Windows ou equivalente  
2. [ ] `ssh -p 2222 "testuser:rio-lab-ssh@192.168.1.180"` → shell no lab (marker `hostname`)  
3. [ ] DBeaver ou psql: `testuser:rio-lab-postgres` @ `192.168.1.180:55432` sslmode=require → `select 1`  
4. [ ] Browser: `https://guac.archgate.com.br` (ou IP+Host) carrega login  

```text
# Ao concluir, preencher:
RESULT operator_os=windows ssh=PASS db=PASS guac=PASS ts=YYYY-MM-DD operador=<nome>
```

## Encerrar waiver

Quando o checklist acima passar uma vez, marcar task 2.5 `[x]` em  
`openspec/changes/add-operator-client-access-standard/tasks.md` e atualizar  
`smoke-evidence-*.md` + `lab-rio-quality.yaml` (`ssh_windows_operador: true`).
