from __future__ import annotations

import json
import socket
import ssl
import time
import urllib.error
import urllib.request
from typing import Any


def tcp_open(host: str, port: int, timeout: float) -> tuple[bool, str]:
    t0 = time.perf_counter()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            ms = int((time.perf_counter() - t0) * 1000)
            return True, f"{host}:{port} OPEN ({ms}ms)"
    except OSError as e:
        return False, f"{host}:{port} FAIL: {e}"


def http_request(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    body: bytes | None = None,
    timeout: float = 15.0,
    allow_redirects: bool = False,
) -> tuple[int, dict[str, str], bytes]:
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("User-Agent", "archgate-rio-quality-report/0.1")
    for k, v in (headers or {}).items():
        req.add_header(k, v)

    ctx = ssl.create_default_context()
    # Staging may present CF certs; default context is fine for public names.
    opener = urllib.request.build_opener(
        urllib.request.HTTPSHandler(context=ctx),
    )
    if not allow_redirects:
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *args, **kwargs):  # type: ignore[no-untyped-def]
                return None

        opener = urllib.request.build_opener(
            urllib.request.HTTPSHandler(context=ctx),
            NoRedirect(),
        )

    try:
        with opener.open(req, timeout=timeout) as resp:
            return resp.status, dict(resp.headers.items()), resp.read()
    except urllib.error.HTTPError as e:
        # HTTPError is also a response (401/403/etc.)
        data = e.read() if hasattr(e, "read") else b""
        return e.code, dict(e.headers.items()) if e.headers else {}, data
    except Exception as e:
        raise RuntimeError(f"{method} {url}: {e}") from e


def http_status(url: str, timeout: float = 15.0) -> tuple[int, str]:
    try:
        code, headers, _ = http_request(url, timeout=timeout)
        loc = headers.get("Location") or headers.get("location") or ""
        return code, loc
    except Exception as e:
        return 0, str(e)


def http_json(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    payload: dict[str, Any] | None = None,
    timeout: float = 15.0,
) -> tuple[int, Any]:
    body = None
    hdrs = {"Accept": "application/json", **(headers or {})}
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        hdrs["Content-Type"] = "application/json"
    code, _, data = http_request(
        url, method=method, headers=hdrs, body=body, timeout=timeout
    )
    if not data:
        return code, None
    try:
        return code, json.loads(data.decode("utf-8", errors="replace"))
    except json.JSONDecodeError:
        return code, data.decode("utf-8", errors="replace")[:500]
