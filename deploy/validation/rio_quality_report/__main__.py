#!/usr/bin/env python3
"""
Rio Quality automated validation → Markdown + JSON report.

Usage (from monorepo root):
  python3 -m deploy.validation.rio_quality_report
  ./deploy/validation/rio_quality_report/run.sh --deep

Optional:
  export UAT_PASS_uat_op_a='…'
  export ARCHGATE_HOST=217.196.60.108 ARCHGATE_SSH_KEY=~/.ssh/linktor_vps_key
  python3 -m deploy.validation.rio_quality_report --deep --remote-peer --devops-scripts
"""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import replace
from datetime import datetime, timezone

# Allow: python3 deploy/validation/rio_quality_report/__main__.py
if __name__ == "__main__" and (__package__ is None or __package__ == ""):
    _root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
    if _root not in sys.path:
        sys.path.insert(0, _root)
    __package__ = "deploy.validation.rio_quality_report"

from .checks import run_all
from .config import Config
from .models import Report
from .report import render_markdown, write_reports


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="ArchGate Rio Quality automated validation report"
    )
    parser.add_argument("--out-dir", default="", help="Output directory for .md/.json")
    parser.add_argument("--stem", default="", help="Filename stem without extension")
    parser.add_argument(
        "--deep",
        action="store_true",
        help="SSH/psql with password (needs UAT_PASS_uat_op_a or RIO_WG_PASSWORD)",
    )
    parser.add_argument(
        "--remote-peer",
        action="store_true",
        help="Probe peers via SSH to ARCHGATE_HOST",
    )
    parser.add_argument(
        "--devops-scripts",
        action="store_true",
        help="Run 67-sprint1-readiness and 74-smoke-grant-bootstrap",
    )
    parser.add_argument(
        "--print",
        action="store_true",
        dest="do_print",
        help="Print Markdown report to stdout",
    )
    args = parser.parse_args(argv)

    cfg = Config.from_env()
    cfg = replace(
        cfg,
        deep=cfg.deep or args.deep,
        run_remote_peer=cfg.run_remote_peer or args.remote_peer,
        run_devops_scripts=cfg.run_devops_scripts or args.devops_scripts,
        out_dir=args.out_dir or cfg.out_dir,
    )

    report = Report(
        started_at=datetime.now(timezone.utc).isoformat(),
        environment={
            "console_url": cfg.console_url,
            "bastion_host": cfg.bastion_host,
            "bastion_ssh_port": str(cfg.bastion_ssh_port),
            "bastion_pg_port": str(cfg.bastion_pg_port),
            "wg_user": cfg.wg_user,
            "deep": str(cfg.deep),
            "has_password": str(bool(cfg.wg_password)),
            "remote_peer": str(cfg.run_remote_peer),
            "vps_host": cfg.vps_host or "",
            "devops_scripts": str(cfg.run_devops_scripts),
            "archgate_cli": cfg.archgate_cli,
        },
    )

    print("=== Rio Quality auto validation ===", file=sys.stderr)
    print(f"console={cfg.console_url} bastion={cfg.bastion_host}", file=sys.stderr)
    print(
        f"deep={cfg.deep} remote_peer={cfg.run_remote_peer} devops={cfg.run_devops_scripts}",
        file=sys.stderr,
    )

    report.checks = run_all(cfg)
    report.finalize()

    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    stem = args.stem or f"smoke-evidence-{day}-rio-quality-auto"
    md_path, json_path = write_reports(report, cfg.out_dir, stem)

    s = report.summary
    print(
        f"PASS={s.get('PASS', 0)} FAIL={s.get('FAIL', 0)} "
        f"WARN={s.get('WARN', 0)} SKIP={s.get('SKIP', 0)} "
        f"→ {'OK' if report.ok else 'NOT OK'}",
        file=sys.stderr,
    )
    print(f"report: {md_path}", file=sys.stderr)
    print(f"json:   {json_path}", file=sys.stderr)

    if args.do_print:
        sys.stdout.write(render_markdown(report))

    return 0 if report.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
