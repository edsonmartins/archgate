#!/usr/bin/env bash
# Lab-only mTLS material for oracle-proxy ↔ plugin (NOT for production PKI).
# Output: /var/lib/archgate/oracle-proxy/certs or ./certs
set -euo pipefail

OUT="${1:-./certs}"
mkdir -p "$OUT"
cd "$OUT"
PASS="${CERT_PASSWORD:-changeit}"

# CA
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt -days 3650 \
  -subj "/CN=archgate-oracle-proxy-lab-ca"

# Server
openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr \
  -subj "/CN=oracle-proxy"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 825
openssl pkcs12 -export -inkey server.key -in server.crt -certfile ca.crt \
  -out server-keystore.p12 -password "pass:${PASS}"

# Client (plugin)
openssl req -newkey rsa:2048 -nodes -keyout client.key -out client.csr \
  -subj "/CN=openbao-oracle-plugin"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out client.crt -days 825
openssl pkcs12 -export -inkey client.key -in client.crt -certfile ca.crt \
  -out client-keystore.p12 -password "pass:${PASS}"

# Truststore (CA only)
keytool -importcert -noprompt -alias lab-ca -file ca.crt \
  -keystore truststore.p12 -storetype PKCS12 -storepass "$PASS" 2>/dev/null \
  || openssl pkcs12 -export -nokeys -in ca.crt -out truststore.p12 -password "pass:${PASS}"

chmod 600 ./*.key ./*.p12 2>/dev/null || true
echo "Lab certs in $OUT (password default: changeit)"
ls -la
