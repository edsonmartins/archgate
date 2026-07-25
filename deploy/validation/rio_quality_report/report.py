from __future__ import annotations

import json
from pathlib import Path

from .models import Report, Status


def render_markdown(report: Report) -> str:
    s = report.summary
    lines = [
        "# Rio Quality — relatório automático de validação",
        "",
        f"| Campo | Valor |",
        f"|-------|--------|",
        f"| Início (UTC) | {report.started_at} |",
        f"| Fim (UTC) | {report.finished_at} |",
        f"| PASS | {s.get('PASS', 0)} |",
        f"| FAIL | {s.get('FAIL', 0)} |",
        f"| WARN | {s.get('WARN', 0)} |",
        f"| SKIP | {s.get('SKIP', 0)} |",
        f"| Decisão automática | **{'PASS' if report.ok else 'FAIL'}** (FAIL se qualquer check FAIL) |",
        "",
        "## Ambiente",
        "",
        "| Key | Value |",
        "|-----|--------|",
    ]
    for k, v in report.environment.items():
        if "password" in k.lower() or "token" in k.lower() and v:
            v = "***"
        lines.append(f"| `{k}` | `{v}` |")

    lines += ["", "## Checks", ""]
    lines += [
        "| ID | Categoria | Status | Título | Detalhe | ms |",
        "|----|-----------|--------|--------|---------|----|",
    ]
    for c in report.checks:
        detail = (c.detail or "").replace("|", "\\|").replace("\n", " ")
        if len(detail) > 120:
            detail = detail[:117] + "…"
        lines.append(
            f"| {c.id} | {c.category} | **{c.status.value}** | {c.title} | {detail} | {c.duration_ms} |"
        )

    fails = [c for c in report.checks if c.status == Status.FAIL]
    warns = [c for c in report.checks if c.status == Status.WARN]
    manuals = [c for c in report.checks if c.status == Status.SKIP and "MANUAL" in (c.detail or "")]

    if fails:
        lines += ["", "## Falhas", ""]
        for c in fails:
            lines.append(f"- **{c.id}** {c.title}: {c.detail}")

    if warns:
        lines += ["", "## Avisos", ""]
        for c in warns:
            lines.append(f"- **{c.id}** {c.title}: {c.detail}")

    if manuals:
        lines += ["", "## Manual (humano / browser)", ""]
        for c in manuals:
            lines.append(f"- [ ] **{c.id}** {c.title} — {c.detail}")

    lines += [
        "",
        "## Próximos passos",
        "",
        "- Preencher residual em [`VALIDACAO-RIO-QUALITY.md`](../../runbooks/sites/VALIDACAO-RIO-QUALITY.md)",
        "- SSH/PG deep: `export UAT_PASS_uat_op_a='…' RIO_DEEP=1`",
        "- Peers no VPS: `export ARCHGATE_HOST=… ARCHGATE_SSH_KEY=… RIO_REMOTE_PEER=1`",
        "- Scripts devops: `RIO_DEVOPS_SCRIPTS=1`",
        "",
    ]
    return "\n".join(lines) + "\n"


def write_reports(report: Report, out_dir: str, stem: str) -> tuple[Path, Path]:
    d = Path(out_dir)
    d.mkdir(parents=True, exist_ok=True)
    md_path = d / f"{stem}.md"
    json_path = d / f"{stem}.json"
    md_path.write_text(render_markdown(report), encoding="utf-8")
    json_path.write_text(
        json.dumps(report.to_dict(), indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return md_path, json_path
