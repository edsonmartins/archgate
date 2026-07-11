#!/usr/bin/env bash
# Dispatcher — escolhe stack de conectividade do piloto lab / connector
# STACK=wireguard|openvpn|socat|openfortivpn
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
STACK="${1:-${STACK:-wireguard}}"

case "$STACK" in
  wireguard|wg)
    exec bash "$ROOT/deploy-wg-piloto-lab.sh"
    ;;
  openvpn|ovpn)
    exec bash "$ROOT/deploy-openvpn-piloto-lab.sh"
    ;;
  socat|legacy)
    exec bash "$ROOT/deploy-piloto-lab.sh"
    ;;
  openfortivpn|forti)
    echo "openfortivpn: sem appliance Forti no lab."
    echo "Scaffold: $ROOT/stacks/openfortivpn/"
    echo "Doc: documentos/runbooks/sites/conectividade-vpn-clientes.md"
    exit 0
    ;;
  *)
    echo "Uso: $0 wireguard|openvpn|socat|openfortivpn" >&2
    exit 1
    ;;
esac
