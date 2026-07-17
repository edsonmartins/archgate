# W0-B — Checklist peer Rio Quality (cliente)

Use este roteiro na conversa com ops do cliente. Preencher e copiar valores para  
[`sites/reais/rio-quality.yaml`](./sites/reais/rio-quality.yaml).

## Mensagem modelo (e-mail / Slack)

```text
Assunto: ArchGate — peer de conectividade piloto (Rio Quality)

Precisamos fechar o caminho bastion → rede Rio Quality para homologação do
ArchGate (acesso privilegiado sem VPN no notebook do operador).

Pedimos, por favor:

1) Stack de VPN / túnel preferida:
   [ ] WireGuard peer institucional
   [ ] OpenVPN (conta de serviço)
   [ ] FortiClient / openfortivpn
   [ ] Cloudflare Tunnel (só se cobrir SSH/DB internos)
   [ ] Outro: ________

2) Subnets internas dos alvos (SSH / Postgres / etc.):
   ________ / ________

3) Hosts prioritários (hostname ou IP interno — NÃO serão dados aos devs):
   - SSH: ________
   - Postgres (se houver): ________ : ____

4) Conta de serviço / peer técnico (credencial só para o connector ArchGate):
   ________

5) Janela para configuração (data/hora):
   ________

6) Contato ops durante o teste:
   ________

Referência de padrão: 1 connector no site → N operadores só via bastion ArchGate.
```

## Após resposta do cliente

1. Atualizar `sites/reais/rio-quality.yaml` (`stack`, `subnets`, `targets`, `inventariado: true`).
2. `bash deploy/connector/...` conforme stack (ver `deploy/connector/onboarding-cliente-peer.md`).
3. Apply targets Warpgate + `TARGET_SECRET_*`.
4. Smoke: `uat-op-a:rio-…@wg` → hostname **real**.
5. Evidência `sites/smoke-evidence-YYYY-MM-DD-cliente-piloto.md`.

## Critério W0-B done

- [ ] Peer up  
- [ ] E2E bastion → host real  
- [ ] Isolamento tenant revalidado  
- [ ] Evidência datada  
