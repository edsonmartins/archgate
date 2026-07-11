# Stack openfortivpn — connector institucional (FortiGate SSL VPN)

Clientes Forti: **uma** sessão `openfortivpn` no connector (`tunnel_agent`).

## Produção (sem lab FortiGate no staging)

```bash
# no runtime ArchGate
apt-get install -y openfortivpn   # ou binário do distro

SITE=cliente-x
mkdir -p /var/lib/archgate/connector/$SITE/forti
chmod 700 /var/lib/archgate/connector/$SITE

# conf (NÃO commitar senha)
cat > /var/lib/archgate/connector/$SITE/forti/openfortivpn.conf <<'EOF'
host = vpn.cliente.example
port = 443
username = svc_archgate
password = <from-secret-store>
# trusted-cert = <sha256 se self-signed>
# set-routes = 1
# set-dns = 0
EOF
chmod 600 /var/lib/archgate/connector/$SITE/forti/openfortivpn.conf

install -m 644 deploy/connector/stacks/openfortivpn/systemd/archgate-connector-forti@.service \
  /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now archgate-connector-forti@$SITE
```

Depois do túnel:

- Confirmar rota para subnets de targets (`ip route`).  
- Publicar forward se necessário (`socat` / iptables DNAT no connector).  
- Warpgate target `host` = IP alcançável **via** túnel Forti (ou 127.0.0.1 no connector com local forward).

## 2FA

Se o cliente exigir OTP por usuário, negociar **conta de serviço** sem 2FA interativo ou token operacional em vault — openfortivpn interativo no notebook do dev **não** é o padrão ArchGate.

## Lab

Sem appliance Forti no lab; validação de path genérico = pilotor WG/OpenVPN.  
Smoke Forti = primeiro site real (task 0.5 inventário `stack: openfortivpn`).
