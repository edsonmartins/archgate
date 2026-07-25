package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"runtime"

)

const version = "0.2.0-dev"

// Execute is the CLI entrypoint (args without program name).
func Execute(args []string) error {
	jsonOut := false
	filtered := make([]string, 0, len(args))
	for _, a := range args {
		if a == "--json" || a == "-j" {
			jsonOut = true
			continue
		}
		filtered = append(filtered, a)
	}
	args = filtered

	if len(args) == 0 {
		printHelp()
		return nil
	}
	cmd := args[0]
	rest := args[1:]
	switch cmd {
	case "help", "-h", "--help":
		printHelp()
		return nil
	case "version", "-v", "--version":
		if jsonOut {
			return printJSON(map[string]any{
				"version": version,
				"os":      runtime.GOOS,
				"arch":    runtime.GOARCH,
			})
		}
		fmt.Printf("archgate %s (%s/%s)\n", version, runtime.GOOS, runtime.GOARCH)
		return nil
	case "login":
		return cmdLogin(rest)
	case "logout":
		return cmdLogout()
	case "status", "whoami":
		return cmdStatus(jsonOut)
	case "ls", "list":
		return cmdLs(jsonOut)
	case "doctor":
		return cmdDoctor(jsonOut)
	case "go":
		return cmdGo(rest)
	case "connect":
		// Canonical dispatcher (was ssh-only alias).
		return cmdGo(rest)
	case "ssh":
		return cmdSSH(rest)
	case "db":
		return cmdDB(rest, jsonOut)
	case "open":
		return cmdOpen(rest)
	case "manager", "open-manager":
		return cmdManager(rest)
	case "config":
		return cmdConfig(rest)
	case "print-ssh":
		return cmdPrintSSH(rest, jsonOut)
	case "auth-header", "api-token":
		return cmdAuthHeader(jsonOut)
	case "print-open":
		return cmdPrintOpen(rest, jsonOut)
	case "wg-user", "warpgate-user":
		return cmdWgUser(rest, jsonOut)
	default:
		return fmt.Errorf("unknown command %q — try archgate help", cmd)
	}
}

func printHelp() {
	fmt.Print(`ArchGate Connect — cliente do operador no bastion (não é VPN do cliente)

  Bastion, not VPN — Forti/OpenVPN ficam no VPS ArchGate.

Uso:
  archgate login                 Login OIDC (browser PKCE)
  archgate login --lab [--user x]  Token lab (homolog / offline API lab)
  archgate logout
  archgate status | whoami
  archgate ls [--json]
  archgate doctor [--json]
  archgate go <target>           Dispatcher: ssh | db | open (pelo catálogo)
  archgate go <t> --terminal     SSH em Terminal.app / xterm
  archgate go <t> --clipboard    DB: copia linha psql
  archgate connect <target>      Alias de go
  archgate ssh <target>          Só SSH Warpgate (interativo)
  archgate ssh <target> --terminal
  archgate print-ssh <target>    Só imprime o comando ssh
  archgate db <target> [--clipboard] [--json]
  archgate open <target>         Browser (Guac / Oracle UI / HTTP)
  archgate manager [--path /x]   Abre ArchGate Manager (admin) no browser
  archgate open-manager          Alias de manager
  archgate auth-header [--json]  Token Bearer p/ BFF (desktop embutido)
  archgate print-open <target>   URL embutível (Guac/HTTP/Oracle) JSON
  archgate wg-user [name]        Ver/definir usuário Warpgate (SSH/DB)
  archgate config apply|remove   ~/.ssh/config.d/archgate
  archgate version

Flags globais:
  --json / -j                    Saída machine-readable (ls, status, doctor, db)

Identidade SSH:
  Warpgate user = ARCHGATE_WG_USER ou credentials.warpgate_user
  (login --lab grava warpgate_user; default lab: uat-op-a)

OIDC:
  access perto de expirar → refresh automático; falha → archgate login

Config:
  ~/.config/archgate/oidc.env    OIDC client secret (auto-load)
  ~/.config/archgate/credentials.json
  ~/.config/archgate/config.json

Docs: documentos/runbooks/archgate-connect.md · ADR-008A
`)
}

func printJSON(v any) error {
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	return enc.Encode(v)
}
