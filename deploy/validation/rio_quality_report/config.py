from __future__ import annotations

import os
from dataclasses import dataclass


def _env(key: str, default: str = "") -> str:
    return (os.environ.get(key) or default).strip()


def _env_int(key: str, default: int) -> int:
    raw = _env(key)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


@dataclass(frozen=True)
class Config:
    """Runtime configuration from environment."""

    # Public edge
    console_url: str = "https://console.archgate.com.br"
    id_url: str = "https://id.archgate.com.br"
    wg_url: str = "https://wg.archgate.com.br"
    guac_url: str = "https://guac.archgate.com.br"
    secrets_url: str = "https://secrets.archgate.com.br"

    # Bastion TCP (CF only fronts HTTPS — SSH/PG on VPS IP)
    bastion_host: str = "217.196.60.108"
    bastion_ssh_port: int = 2222
    bastion_pg_port: int = 55432

    # Operator identity for deep checks
    wg_user: str = "uat-op-a"
    wg_password: str = ""  # UAT_PASS_uat_op_a or RIO_WG_PASSWORD
    lab_token: str = "lab-rio-report"

    # Targets
    target_ssh_lab: str = "rio-lab-ssh"
    target_ssh_aws: str = "rio-aws-api-b"
    target_ssh_deny: str = "marra-lab-ssh"
    target_pg_lab: str = "rio-lab-postgres"
    target_pg_aws: str = "rio-aws-pg-a"
    pg_database: str = "archgate_lab"

    # Timeouts
    http_timeout: float = 15.0
    tcp_timeout: float = 5.0
    ssh_timeout: float = 12.0

    # Optional VPS remote (peer probes)
    vps_host: str = ""
    vps_user: str = "root"
    vps_ssh_key: str = ""
    vps_ssh_port: int = 22

    # Paths
    archgate_cli: str = ""
    devops_dir: str = ""
    out_dir: str = ""

    # Modes
    deep: bool = False  # attempt SSH/psql with password when set
    run_remote_peer: bool = False
    run_devops_scripts: bool = False

    @classmethod
    def from_env(cls) -> "Config":
        home = os.path.expanduser("~")
        default_cli = os.path.join(home, ".local", "bin", "archgate")
        default_devops = os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "..",
                "..",
                "..",
                "..",
                "archgate-devops",
            )
        )
        # Prefer sibling of archgate monorepo
        mono_root = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "..", "..")
        )
        sibling = os.path.join(os.path.dirname(mono_root), "archgate-devops")
        if os.path.isdir(sibling):
            default_devops = sibling

        pw = _env("RIO_WG_PASSWORD") or _env("UAT_PASS_uat_op_a") or _env(
            "WARPGATE_OPERATOR_PASSWORD"
        )
        deep = _env("RIO_DEEP", "0") in ("1", "true", "yes")
        if pw:
            deep = True

        return cls(
            console_url=_env("CONSOLE_URL", "https://console.archgate.com.br").rstrip(
                "/"
            ),
            id_url=_env("ID_URL", "https://id.archgate.com.br").rstrip("/"),
            wg_url=_env("WG_URL", "https://wg.archgate.com.br").rstrip("/"),
            guac_url=_env("GUAC_URL", "https://guac.archgate.com.br").rstrip("/"),
            secrets_url=_env("SECRETS_URL", "https://secrets.archgate.com.br").rstrip(
                "/"
            ),
            bastion_host=_env("BASTION_HOST", "217.196.60.108"),
            bastion_ssh_port=_env_int("BASTION_SSH_PORT", 2222),
            bastion_pg_port=_env_int("BASTION_PG_PORT", 55432),
            wg_user=_env("RIO_WG_USER", "uat-op-a"),
            wg_password=pw,
            lab_token=_env("RIO_LAB_TOKEN", "lab-rio-report"),
            target_ssh_lab=_env("RIO_TARGET_SSH_LAB", "rio-lab-ssh"),
            target_ssh_aws=_env("RIO_TARGET_SSH_AWS", "rio-aws-api-b"),
            target_ssh_deny=_env("RIO_TARGET_SSH_DENY", "marra-lab-ssh"),
            target_pg_lab=_env("RIO_TARGET_PG_LAB", "rio-lab-postgres"),
            target_pg_aws=_env("RIO_TARGET_PG_AWS", "rio-aws-pg-a"),
            pg_database=_env("RIO_PG_DATABASE", "archgate_lab"),
            http_timeout=float(_env("RIO_HTTP_TIMEOUT", "15") or "15"),
            tcp_timeout=float(_env("RIO_TCP_TIMEOUT", "5") or "5"),
            ssh_timeout=float(_env("RIO_SSH_TIMEOUT", "12") or "12"),
            vps_host=_env("ARCHGATE_HOST") or _env("RIO_VPS_HOST"),
            vps_user=_env("ARCHGATE_SSH_USER", "root"),
            vps_ssh_key=_env("ARCHGATE_SSH_KEY")
            or os.path.expanduser("~/.ssh/linktor_vps_key"),
            vps_ssh_port=_env_int("ARCHGATE_SSH_PORT", 22),
            archgate_cli=_env("ARCHGATE_CLI", default_cli if os.path.isfile(default_cli) else "archgate"),
            devops_dir=_env("ARCHGATE_DEVOPS", default_devops),
            out_dir=_env(
                "RIO_REPORT_DIR",
                os.path.join(mono_root, "documentos", "evidence"),
            ),
            deep=deep,
            run_remote_peer=_env("RIO_REMOTE_PEER", "0") in ("1", "true", "yes")
            or bool(_env("ARCHGATE_HOST")),
            run_devops_scripts=_env("RIO_DEVOPS_SCRIPTS", "0") in ("1", "true", "yes"),
        )
