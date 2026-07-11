# Stack OpenVPN — connector institucional

Clientes com portal/profile **OpenVPN**: o ArchGate sobe **um** cliente OpenVPN no connector (`tunnel_agent`), não no notebook do operador.

## Lab

```bash
bash deploy/connector/deploy-openvpn-piloto-lab.sh
MODE=openvpn bash deploy/connector/smoke-connector-piloto.sh
```

Path:

```
Warpgate → platform connector (OpenVPN client + socat)
              ~~~ OpenVPN ~~~
         → site (OpenVPN server + SSH só na site-net)
```

## Produção

1. Obter `.ovpn` / certs de **conta de serviço** (não usuário pessoal).  
2. Guardar em `/var/lib/archgate/connector/<site>/openvpn/` (mode 600).  
3. Usar unit: `archgate-connector-openvpn@.service` (ver `systemd/`).  
4. After-up: rotas para `subnets_alvo` + targets Warpgate apontando ao connector.  

Ver: `documentos/runbooks/sites/conectividade-vpn-clientes.md`.
