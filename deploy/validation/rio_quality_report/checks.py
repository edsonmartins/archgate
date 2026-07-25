from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from typing import Callable

from .config import Config
from .httputil import http_json, http_status, tcp_open
from .models import CheckResult, Status


def _run(
    cid: str,
    category: str,
    title: str,
    fn: Callable[[], tuple[Status, str, dict]],
) -> CheckResult:
    t0 = time.perf_counter()
    try:
        status, detail, evidence = fn()
    except Exception as e:
        status, detail, evidence = Status.FAIL, str(e), {}
    ms = int((time.perf_counter() - t0) * 1000)
    return CheckResult(
        id=cid,
        category=category,
        title=title,
        status=status,
        detail=detail,
        duration_ms=ms,
        evidence=evidence,
    )


def check_https_edge(cfg: Config) -> list[CheckResult]:
    out: list[CheckResult] = []

    for cid, name, url, ok_codes in [
        ("P1", "Console HTTPS", cfg.console_url, {200, 301, 302, 303, 307, 308}),
        ("P2", "Kanidm id HTTPS", cfg.id_url, {200, 301, 302, 303, 307, 308}),
        ("P3", "Warpgate UI HTTPS", cfg.wg_url, {200, 301, 302, 303, 307, 308}),
        ("P4", "Guacamole HTTPS", cfg.guac_url, {200, 301, 302, 303, 307, 308}),
    ]:

        def _fn(
            u=url, codes=ok_codes
        ) -> tuple[Status, str, dict]:
            code, loc = http_status(u, cfg.http_timeout)
            if code in codes:
                return (
                    Status.PASS,
                    f"HTTP {code}" + (f" → {loc}" if loc else ""),
                    {"status": code, "location": loc},
                )
            if code == 0:
                return Status.FAIL, f"unreachable: {loc}", {}
            return Status.FAIL, f"HTTP {code} (expected {sorted(codes)})", {"status": code}

        out.append(_run(cid, "platform", name, _fn))
    return out


def check_bastion_tcp(cfg: Config) -> list[CheckResult]:
    out: list[CheckResult] = []

    def ssh() -> tuple[Status, str, dict]:
        ok, msg = tcp_open(cfg.bastion_host, cfg.bastion_ssh_port, cfg.tcp_timeout)
        return (Status.PASS if ok else Status.FAIL), msg, {}

    def pg() -> tuple[Status, str, dict]:
        ok, msg = tcp_open(cfg.bastion_host, cfg.bastion_pg_port, cfg.tcp_timeout)
        return (Status.PASS if ok else Status.FAIL), msg, {}

    out.append(_run("P5", "platform", "Bastion SSH TCP", ssh))
    out.append(_run("P6", "platform", "Bastion Postgres TCP", pg))
    return out


def check_bootstrap(cfg: Config) -> list[CheckResult]:
    out: list[CheckResult] = []
    api = f"{cfg.console_url}/api/unified/v1/operator/bootstrap"

    def unauth() -> tuple[Status, str, dict]:
        code, body = http_json(api, timeout=cfg.http_timeout)
        if code == 401:
            return Status.PASS, "401 Unauthorized (expected)", {"status": code}
        return Status.FAIL, f"expected 401 got {code}: {body!r}"[:200], {"status": code}

    def lab() -> tuple[Status, str, dict]:
        code, body = http_json(
            api,
            headers={"Authorization": f"Bearer {cfg.lab_token}"},
            timeout=cfg.http_timeout,
        )
        if code != 200 or not isinstance(body, dict):
            return (
                Status.FAIL,
                f"expected 200 JSON got {code}: {body!r}"[:240],
                {"status": code},
            )
        conns = body.get("connections") or []
        bastion = body.get("bastion") or {}
        targets = [c.get("target") for c in conns if isinstance(c, dict)]
        rio = [t for t in targets if t and str(t).startswith("rio-")]
        detail = (
            f"{len(conns)} connections · rio={len(rio)} · "
            f"ssh={bastion.get('ssh_host')}:{bastion.get('ssh_port')}"
        )
        # Expect some Rio targets when SoT is loaded
        if len(conns) == 0:
            return Status.WARN, detail + " (empty catalog)", {"targets": targets}
        if not rio:
            return Status.WARN, detail + " (no rio-* targets)", {"targets": targets}
        return Status.PASS, detail, {
            "count": len(conns),
            "rio_count": len(rio),
            "targets": targets[:30],
            "bastion": bastion,
        }

    out.append(_run("B1", "bootstrap", "Bootstrap unauth → 401", unauth))
    out.append(_run("B2", "bootstrap", "Bootstrap lab bearer → catalog", lab))
    return out


def check_sessions_api(cfg: Config) -> list[CheckResult]:
    def _fn() -> tuple[Status, str, dict]:
        url = f"{cfg.console_url}/api/unified/v1/sessions"
        code, body = http_json(
            url,
            method="POST",
            headers={"Authorization": f"Bearer {cfg.lab_token}"},
            payload={
                "target": cfg.target_ssh_lab,
                "protocol": "ssh",
                "connection_id": f"lab:{cfg.target_ssh_lab}",
            },
            timeout=cfg.http_timeout,
        )
        if code in (200, 400, 403):
            # 200 ok; 400/403 means auth worked but catalog mapping may differ
            st = Status.PASS if code == 200 else Status.WARN
            return st, f"HTTP {code}: {str(body)[:180]}", {"status": code, "body": body}
        if code == 401:
            return Status.FAIL, "401 — Bearer not accepted for sessions", {"status": code}
        return Status.WARN, f"HTTP {code}", {"status": code, "body": body}

    return [
        _run("B3", "bootstrap", "Sessions API (lab bearer)", _fn),
    ]


def check_archgate_cli(cfg: Config) -> list[CheckResult]:
    out: list[CheckResult] = []
    cli = shutil.which(cfg.archgate_cli) or (
        cfg.archgate_cli if os.path.isfile(cfg.archgate_cli) else None
    )

    def which() -> tuple[Status, str, dict]:
        if not cli:
            return Status.SKIP, "archgate CLI not found on PATH", {}
        try:
            r = subprocess.run(
                [cli, "version"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if r.returncode == 0:
                return Status.PASS, (r.stdout or r.stderr).strip()[:120], {}
            return Status.FAIL, (r.stderr or r.stdout or "exit non-zero")[:200], {}
        except Exception as e:
            return Status.FAIL, str(e), {}

    out.append(_run("I1", "connect", "archgate CLI version", which))

    if not cli:
        out.append(
            CheckResult(
                id="I2",
                category="connect",
                title="archgate doctor --json",
                status=Status.SKIP,
                detail="no CLI",
            )
        )
        return out

    def doctor() -> tuple[Status, str, dict]:
        env = os.environ.copy()
        env.setdefault("ARCHGATE_MOCK", "0")
        r = subprocess.run(
            [cli, "doctor", "--json"],
            capture_output=True,
            text=True,
            timeout=30,
            env=env,
        )
        raw = (r.stdout or "").strip()
        if not raw:
            return Status.WARN, (r.stderr or "empty doctor output")[:200], {}
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return Status.WARN, raw[:200], {}
        checks = data.get("checks") or []
        fails = [c for c in checks if isinstance(c, dict) and not c.get("ok")]
        if fails:
            names = ", ".join(c.get("name", "?") for c in fails)
            return Status.WARN, f"doctor soft-fail: {names}", {"checks": checks}
        return Status.PASS, f"{len(checks)} checks OK", {"checks": checks}

    out.append(_run("I2", "connect", "archgate doctor --json", doctor))
    return out


def check_ssh_deep(cfg: Config) -> list[CheckResult]:
    """Optional SSH via bastion using sshpass when password provided."""
    out: list[CheckResult] = []
    if not cfg.deep or not cfg.wg_password:
        out.append(
            CheckResult(
                id="S0",
                category="ssh",
                title="SSH deep checks",
                status=Status.SKIP,
                detail="Set RIO_WG_PASSWORD or UAT_PASS_uat_op_a (and RIO_DEEP=1) for live SSH",
            )
        )
        return out

    sshpass = shutil.which("sshpass")
    if not sshpass:
        out.append(
            CheckResult(
                id="S0",
                category="ssh",
                title="SSH deep checks",
                status=Status.SKIP,
                detail="sshpass not installed (brew install sshpass / apt install sshpass)",
            )
        )
        return out

    def try_ssh(target: str, expect_ok: bool) -> tuple[Status, str, dict]:
        user = f"{cfg.wg_user}:{target}"
        dest = f"{user}@{cfg.bastion_host}"
        cmd = [
            sshpass,
            "-p",
            cfg.wg_password,
            "ssh",
            "-p",
            str(cfg.bastion_ssh_port),
            "-o",
            "StrictHostKeyChecking=accept-new",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "-o",
            "GlobalKnownHostsFile=/dev/null",
            "-o",
            "PreferredAuthentications=password",
            "-o",
            "PubkeyAuthentication=no",
            "-o",
            f"ConnectTimeout={int(cfg.ssh_timeout)}",
            dest,
            "echo RIO_SSH_OK; hostname; whoami",
        ]
        try:
            r = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=cfg.ssh_timeout + 5,
            )
        except subprocess.TimeoutExpired:
            ok = False
            detail = "timeout"
            out_s, err_s = "", "timeout"
        else:
            out_s, err_s = r.stdout or "", r.stderr or ""
            ok = r.returncode == 0 and "RIO_SSH_OK" in out_s

        if expect_ok:
            if ok:
                return Status.PASS, out_s.strip().replace("\n", " · ")[:200], {
                    "stdout": out_s[-500:],
                }
            # Permission denied vs network
            blob = (out_s + err_s).lower()
            if "permission denied" in blob or "denied" in blob:
                return Status.FAIL, f"auth/target denied: {err_s[:160]}", {}
            return Status.FAIL, (err_s or out_s or "ssh failed")[:200], {}
        # expect deny
        if ok:
            return Status.FAIL, "isolation FAIL — session succeeded", {"stdout": out_s}
        blob = (out_s + err_s).lower()
        if "permission denied" in blob or "denied" in blob or "not allowed" in blob:
            return Status.PASS, "denied as expected", {}
        return Status.WARN, f"failed but not clearly deny: {(err_s or out_s)[:160]}", {}

    out.append(
        _run(
            "S1",
            "ssh",
            f"SSH lab {cfg.target_ssh_lab}",
            lambda: try_ssh(cfg.target_ssh_lab, True),
        )
    )
    out.append(
        _run(
            "S2",
            "ssh",
            f"SSH AWS {cfg.target_ssh_aws}",
            lambda: try_ssh(cfg.target_ssh_aws, True),
        )
    )
    out.append(
        _run(
            "G1",
            "isolation",
            f"Deny {cfg.target_ssh_deny}",
            lambda: try_ssh(cfg.target_ssh_deny, False),
        )
    )
    return out


def check_psql_deep(cfg: Config) -> list[CheckResult]:
    if not cfg.deep or not cfg.wg_password:
        return [
            CheckResult(
                id="C0",
                category="postgres",
                title="Postgres deep checks",
                status=Status.SKIP,
                detail="Set RIO_WG_PASSWORD for live psql",
            )
        ]
    if not shutil.which("psql"):
        return [
            CheckResult(
                id="C0",
                category="postgres",
                title="Postgres deep checks",
                status=Status.SKIP,
                detail="psql not on PATH",
            )
        ]

    def try_pg(target: str, db: str) -> tuple[Status, str, dict]:
        user = f"{cfg.wg_user}:{target}"
        env = os.environ.copy()
        env["PGPASSWORD"] = cfg.wg_password
        conn = (
            f"host={cfg.bastion_host} port={cfg.bastion_pg_port} "
            f"user={user} dbname={db} sslmode=require connect_timeout={int(cfg.tcp_timeout)}"
        )
        r = subprocess.run(
            ["psql", conn, "-tAc", "select 1"],
            capture_output=True,
            text=True,
            timeout=20,
            env=env,
        )
        if r.returncode == 0 and "1" in (r.stdout or ""):
            return Status.PASS, f"select 1 OK ({target})", {}
        return Status.FAIL, (r.stderr or r.stdout or "psql failed")[:220], {}

    return [
        _run(
            "C1",
            "postgres",
            f"psql lab {cfg.target_pg_lab}",
            lambda: try_pg(cfg.target_pg_lab, cfg.pg_database),
        ),
        _run(
            "C2",
            "postgres",
            f"psql AWS {cfg.target_pg_aws}",
            lambda: try_pg(cfg.target_pg_aws, cfg.pg_database),
        ),
    ]


def check_remote_peer(cfg: Config) -> list[CheckResult]:
    if not cfg.run_remote_peer or not cfg.vps_host:
        return [
            CheckResult(
                id="A0",
                category="peer",
                title="Remote peer probes",
                status=Status.SKIP,
                detail="Set ARCHGATE_HOST (+ key) and RIO_REMOTE_PEER=1",
            )
        ]

    key = cfg.vps_ssh_key
    if key and not os.path.isfile(key):
        return [
            CheckResult(
                id="A0",
                category="peer",
                title="Remote peer probes",
                status=Status.SKIP,
                detail=f"SSH key not found: {key}",
            )
        ]

    def remote(script: str) -> tuple[int, str, str]:
        cmd = [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "StrictHostKeyChecking=accept-new",
            "-o",
            "ConnectTimeout=10",
            "-p",
            str(cfg.vps_ssh_port),
        ]
        if key:
            cmd += ["-i", key, "-o", "IdentitiesOnly=yes"]
        cmd += [f"{cfg.vps_user}@{cfg.vps_host}", script]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return r.returncode, r.stdout or "", r.stderr or ""

    def peer_status() -> tuple[Status, str, dict]:
        code, out, err = remote(
            "set -e; "
            "echo '=== units ==='; "
            "systemctl is-active archgate-connector-openvpn@rio-aws 2>/dev/null || "
            "systemctl is-active 'archgate-connector*' 2>/dev/null | head -5 || true; "
            "ip -br a 2>/dev/null | egrep 'tun|ppp|wg' || true; "
            "echo '=== probes ==='; "
            "for h in 10.0.25.18 10.0.25.62 10.0.31.102; do "
            "  (timeout 3 bash -c \"echo >/dev/tcp/$h/22\" && echo $h:22 OPEN) 2>/dev/null || echo $h:22 CLOSED; "
            "done; "
            "for h in 192.168.0.214; do "
            "  (timeout 3 bash -c \"echo >/dev/tcp/$h/22\" && echo $h:22 OPEN) 2>/dev/null || echo $h:22 CLOSED; "
            "done"
        )
        text = (out + err).strip()
        if code != 0 and not out:
            return Status.FAIL, f"ssh failed: {err[:200]}", {}
        open_aws = sum(1 for h in ("10.0.25.18", "10.0.25.62", "10.0.31.102") if f"{h}:22 OPEN" in text)
        if open_aws >= 1:
            st = Status.PASS
        elif "OPEN" in text:
            st = Status.WARN
        else:
            st = Status.WARN
        return st, text.replace("\n", " · ")[:280], {"raw": text[-2000:]}

    return [_run("A1", "peer", "VPS peer units + host probes", peer_status)]


def check_devops_scripts(cfg: Config) -> list[CheckResult]:
    if not cfg.run_devops_scripts:
        return [
            CheckResult(
                id="D0",
                category="devops",
                title="Devops smoke scripts",
                status=Status.SKIP,
                detail="Set RIO_DEVOPS_SCRIPTS=1 to run 67/74",
            )
        ]
    root = cfg.devops_dir
    if not os.path.isdir(root):
        return [
            CheckResult(
                id="D0",
                category="devops",
                title="Devops smoke scripts",
                status=Status.SKIP,
                detail=f"devops dir missing: {root}",
            )
        ]

    out: list[CheckResult] = []
    for cid, name, rel in [
        ("D1", "67-sprint1-readiness", "scripts/67-sprint1-readiness.sh"),
        ("D2", "74-smoke-grant-bootstrap", "scripts/74-smoke-grant-bootstrap.sh"),
    ]:
        path = os.path.join(root, rel)
        if not os.path.isfile(path):
            out.append(
                CheckResult(
                    id=cid,
                    category="devops",
                    title=name,
                    status=Status.SKIP,
                    detail=f"missing {path}",
                )
            )
            continue

        def _fn(p=path, n=name) -> tuple[Status, str, dict]:
            r = subprocess.run(
                ["bash", p],
                capture_output=True,
                text=True,
                timeout=180,
                cwd=os.path.dirname(p),
            )
            blob = (r.stdout or "") + (r.stderr or "")
            if r.returncode == 0:
                return Status.PASS, f"{n} exit 0", {"tail": blob[-800:]}
            return Status.FAIL, f"{n} exit {r.returncode}", {"tail": blob[-800:]}

        out.append(_run(cid, "devops", name, _fn))
    return out


def manual_placeholders() -> list[CheckResult]:
    """Document checks that require a human browser / UI."""
    items = [
        ("H1", "admin", "Manager /sites/rio_quality visual", "Browser: dual connectors + targets"),
        ("H2", "admin", "Viewer deny UI", "Login uat-viewer — sem mutações"),
        ("F1", "guac", "Guacamole SSO visual", "Browser guac.archgate.com.br"),
        ("D3", "oracle", "Oracle lease E2E real", "Manager /oracle + JDBC mock=false"),
        ("I5", "connect", "Connect preferências terminal", "UI Preferências global/por target"),
        ("U1", "uat", "Assinatura §6.2", "PLAN-HOMOLOGACAO-MVP.md"),
    ]
    return [
        CheckResult(
            id=i,
            category=c,
            title=t,
            status=Status.SKIP,
            detail=f"MANUAL: {d}",
        )
        for i, c, t, d in items
    ]


def run_all(cfg: Config) -> list[CheckResult]:
    checks: list[CheckResult] = []
    checks += check_https_edge(cfg)
    checks += check_bastion_tcp(cfg)
    checks += check_bootstrap(cfg)
    checks += check_sessions_api(cfg)
    checks += check_archgate_cli(cfg)
    checks += check_ssh_deep(cfg)
    checks += check_psql_deep(cfg)
    checks += check_remote_peer(cfg)
    checks += check_devops_scripts(cfg)
    checks += manual_placeholders()
    return checks
