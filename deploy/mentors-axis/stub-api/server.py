#!/usr/bin/env python3
"""
Mentors Axis API stub — contrato mínimo para CP-7 live no lab.

Alinha com mentors-axis-server-api:
  POST /api/v1/auth/authenticate  {email,password} → access_token
  GET  /api/v1/proprietario/findAll?page&size → Spring Page

Não substitui o Axis real; serve para validar o control plane.
"""
from __future__ import annotations

import json
import os
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get("AXIS_STUB_PORT", "9030"))
TOKEN = os.environ.get("AXIS_STUB_TOKEN", "archgate-lab-axis-token")
EMAIL = os.environ.get("AXIS_STUB_EMAIL", "admin@axis.lab")
PASSWORD = os.environ.get("AXIS_STUB_PASSWORD", "AxisLab2026!")

PROPRIETARIOS = [
    {
        "id": str(uuid.uuid5(uuid.NAMESPACE_DNS, "rio-quality")),
        "code": "rio_quality",
        "descricao": "Rio Quality",
        "cnpj": "12.345.678/0001-90",
        "status": "ATIVO",
        "adminEmail": "admin@rioquality.example",
    },
    {
        "id": str(uuid.uuid5(uuid.NAMESPACE_DNS, "grupo-marra")),
        "code": "grupo_marra",
        "descricao": "Grupo Marra",
        "cnpj": "98.765.432/0001-10",
        "status": "ATIVO",
        "adminEmail": "admin@grupomarra.example",
    },
    {
        "id": str(uuid.uuid5(uuid.NAMESPACE_DNS, "acme-industria")),
        "code": "acme",
        "descricao": "ACME Indústria",
        "cnpj": "11.222.333/0001-44",
        "status": "ATIVO",
        "adminEmail": "ops@acme.example",
    },
]


def json_response(handler: BaseHTTPRequestHandler, code: int, body: dict | list) -> None:
    data = json.dumps(body).encode()
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header(
        "Access-Control-Allow-Headers",
        "Authorization,Content-Type,X-TENANT-IDs",
    )
    handler.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
    handler.end_headers()
    handler.wfile.write(data)


def auth_ok(handler: BaseHTTPRequestHandler) -> bool:
    auth = handler.headers.get("Authorization", "")
    if auth == f"Bearer {TOKEN}":
        return True
    if auth.startswith("Bearer ") and auth[7:] == TOKEN:
        return True
    return False


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        print(f"[axis-stub] {self.address_string()} {fmt % args}")

    def do_OPTIONS(self) -> None:
        json_response(self, 200, {"ok": True})

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            body = json.loads(raw.decode() or "{}")
        except json.JSONDecodeError:
            json_response(self, 400, {"error": "invalid json"})
            return

        if path in (
            "/api/v1/auth/authenticate",
            "/api/v1/autenticacao/authenticate",
            "/api/v1/autenticacao/login",
        ):
            email = body.get("email") or body.get("username")
            password = body.get("password")
            if email == EMAIL and password == PASSWORD:
                json_response(
                    self,
                    200,
                    {
                        "access_token": TOKEN,
                        "refresh_token": "refresh-lab",
                        "expires_in": 86400,
                        "token_type": "BEARER",
                    },
                )
            else:
                json_response(self, 401, {"error": "Bad credentials"})
            return

        json_response(self, 404, {"error": f"not found {path}"})

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)

        if path in ("/", "/health", "/actuator/health"):
            json_response(self, 200, {"status": "UP", "service": "axis-stub"})
            return

        if path == "/api/v1/proprietario/findAll":
            if not auth_ok(self):
                json_response(self, 401, {"error": "Unauthorized"})
                return
            page = int((qs.get("page") or ["0"])[0])
            size = int((qs.get("size") or ["100"])[0])
            start = page * size
            chunk = PROPRIETARIOS[start : start + size]
            total = len(PROPRIETARIOS)
            total_pages = max(1, (total + size - 1) // size)
            json_response(
                self,
                200,
                {
                    "content": chunk,
                    "totalElements": total,
                    "totalPages": total_pages,
                    "size": size,
                    "number": page,
                    "first": page == 0,
                    "last": page >= total_pages - 1,
                },
            )
            return

        json_response(self, 404, {"error": f"not found {path}"})


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"axis-stub listening on :{PORT} email={EMAIL}")
    server.serve_forever()


if __name__ == "__main__":
    main()
