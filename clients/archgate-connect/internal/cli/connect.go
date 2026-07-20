package cli

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/api"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/config"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/sshcfg"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/util"
)

// dispatchAction is the canonical connect action for a catalog entry.
type dispatchAction string

const (
	actionSSH  dispatchAction = "ssh"
	actionDB   dispatchAction = "db"
	actionOpen dispatchAction = "open"
)

// classifyConn chooses ssh | db | open from protocol/engine (single policy).
func classifyConn(conn *api.Connection) dispatchAction {
	if conn == nil {
		return actionOpen
	}
	p := strings.ToLower(conn.Protocol)
	e := strings.ToLower(conn.Engine)
	t := strings.ToLower(conn.Target)
	if e == "guacamole" || p == "http" || p == "https" || p == "oracle" || strings.Contains(t, "oracle") {
		return actionOpen
	}
	if p == "postgres" || p == "postgresql" || p == "mysql" {
		return actionDB
	}
	if p == "ssh" || e == "warpgate" {
		return actionSSH
	}
	return actionOpen
}

// cmdGo is the canonical dispatcher: open / db / ssh based on catalog.
// Flags: --terminal (SSH), --clipboard (DB copy psql line).
func cmdGo(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: archgate go <target> [--terminal] [--clipboard]")
	}
	target := args[0]
	terminal := false
	clipboard := false
	rest := []string{}
	for i := 1; i < len(args); i++ {
		switch args[i] {
		case "--terminal", "-t":
			terminal = true
		case "--clipboard", "--copy", "-c":
			clipboard = true
		case "--":
			rest = append(rest, args[i+1:]...)
			i = len(args)
		default:
			rest = append(rest, args[i])
		}
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	b, err := loadBootstrap(cfg)
	if err != nil {
		return err
	}
	conn, err := findConn(b.Connections, target)
	if err != nil {
		return err
	}
	switch classifyConn(conn) {
	case actionOpen:
		return cmdOpen([]string{conn.Target})
	case actionDB:
		dbArgs := []string{conn.Target}
		if clipboard {
			dbArgs = append(dbArgs, "--clipboard")
		}
		return cmdDB(dbArgs, false)
	default:
		sshArgs := []string{conn.Target}
		if terminal {
			sshArgs = append(sshArgs, "--terminal")
		}
		if len(rest) > 0 {
			sshArgs = append(sshArgs, "--")
			sshArgs = append(sshArgs, rest...)
		}
		return cmdSSH(sshArgs)
	}
}

func cmdPrintSSH(args []string, jsonOut bool) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: archgate print-ssh <target>")
	}
	cfg, conn, user, err := resolveSSH(args[0])
	if err != nil {
		return err
	}
	if classifyConn(conn) != actionSSH {
		return fmt.Errorf("target %s is %s/%s — not SSH (use: archgate go %s)", conn.Target, conn.Engine, conn.Protocol, conn.Target)
	}
	proxyUser := fmt.Sprintf("%s:%s", user, conn.Target)
	cmd := fmt.Sprintf("ssh -p %d -o StrictHostKeyChecking=accept-new '%s@%s'",
		cfg.Bastion.SSHPort, proxyUser, cfg.Bastion.SSHHost)
	if jsonOut {
		return printJSON(map[string]any{
			"command":    cmd,
			"host":       cfg.Bastion.SSHHost,
			"port":       cfg.Bastion.SSHPort,
			"user":       proxyUser,
			"target":     conn.Target,
			"operator":   user,
			"ssh_config": fmt.Sprintf("archgate-%s", util.Sanitize(conn.Target)),
		})
	}
	fmt.Println(cmd)
	return nil
}

func resolveSSH(target string) (*config.File, *api.Connection, string, error) {
	if !util.TargetSafe(target) {
		return nil, nil, "", fmt.Errorf("invalid target %q (use letters, digits, ._- only)", target)
	}
	cfg, err := config.Load()
	if err != nil {
		return nil, nil, "", err
	}
	b, err := loadBootstrap(cfg)
	if err != nil {
		return nil, nil, "", err
	}
	conn, err := findConn(b.Connections, target)
	if err != nil {
		return nil, nil, "", err
	}
	user, err := resolveWarpgateUser(cfg)
	if err != nil {
		return nil, nil, "", err
	}
	return cfg, conn, user, nil
}

func cmdSSH(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: archgate ssh <target> [--terminal]")
	}
	target := args[0]
	terminal := false
	extra := []string{}
	for i := 1; i < len(args); i++ {
		if args[i] == "--terminal" || args[i] == "-t" {
			terminal = true
			continue
		}
		if args[i] == "--" {
			extra = append(extra, args[i+1:]...)
			break
		}
		extra = append(extra, args[i])
	}
	cfg, conn, user, err := resolveSSH(target)
	if err != nil {
		return err
	}
	if act := classifyConn(conn); act != actionSSH {
		return fmt.Errorf("target %s is %s/%s — use: archgate go %s (or archgate %s %s)",
			target, conn.Engine, conn.Protocol, target, act, target)
	}
	proxyUser := fmt.Sprintf("%s:%s", user, conn.Target)
	sshArgs := []string{
		"-p", strconv.Itoa(cfg.Bastion.SSHPort),
		"-o", "StrictHostKeyChecking=accept-new",
		fmt.Sprintf("%s@%s", proxyUser, cfg.Bastion.SSHHost),
	}
	sshArgs = append(sshArgs, extra...)
	line := "ssh " + strings.Join(sshArgs, " ")
	fmt.Printf("→ %s\n", line)
	if cfg.Creds.LabToken != "" {
		fmt.Printf("Warpgate password: use operator password for %s (not lab catalog nickname).\n", user)
	}

	if terminal {
		return openInTerminal(line)
	}
	cmd := exec.Command("ssh", sshArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func openInTerminal(sshLine string) error {
	switch runtime.GOOS {
	case "darwin":
		// %q gives a safe AppleScript string literal
		script := fmt.Sprintf(`tell application "Terminal"
  activate
  do script %q
end tell`, sshLine)
		return exec.Command("osascript", "-e", script).Start()
	case "linux":
		if _, err := exec.LookPath("x-terminal-emulator"); err == nil {
			return exec.Command("x-terminal-emulator", "-e", "bash", "-lc", sshLine+"; exec bash").Start()
		}
		if _, err := exec.LookPath("gnome-terminal"); err == nil {
			return exec.Command("gnome-terminal", "--", "bash", "-lc", sshLine+"; exec bash").Start()
		}
		return fmt.Errorf("no terminal emulator found; run without --terminal")
	default:
		return fmt.Errorf("--terminal not supported on %s; run without it", runtime.GOOS)
	}
}

func cmdDB(args []string, jsonOut bool) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: archgate db <target> [--clipboard]")
	}
	target := args[0]
	clipboard := false
	for _, a := range args[1:] {
		if a == "--clipboard" || a == "--copy" || a == "-c" {
			clipboard = true
		}
	}
	if !util.TargetSafe(target) {
		return fmt.Errorf("invalid target %q (use letters, digits, ._- only)", target)
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	b, err := loadBootstrap(cfg)
	if err != nil {
		return err
	}
	conn, err := findConn(b.Connections, target)
	if err != nil {
		return err
	}
	user, err := resolveWarpgateUser(cfg)
	if err != nil {
		return err
	}
	proxyUser := fmt.Sprintf("%s:%s", user, conn.Target)
	psql := fmt.Sprintf(`psql "host=%s port=%d user=%s dbname=%s sslmode=require"`,
		cfg.Bastion.PGHost, cfg.Bastion.PGPort, proxyUser, cfg.Bastion.PGDatabase)
	if jsonOut {
		return printJSON(map[string]any{
			"host":     cfg.Bastion.PGHost,
			"port":     cfg.Bastion.PGPort,
			"database": cfg.Bastion.PGDatabase,
			"username": proxyUser,
			"sslmode":  "require",
			"psql":     psql,
			"note":     "Password is your Warpgate/operator credential, not the database password",
		})
	}
	fmt.Println("Postgres via Warpgate bastion (not target IP)")
	fmt.Printf("  Host:     %s\n", cfg.Bastion.PGHost)
	fmt.Printf("  Port:     %d\n", cfg.Bastion.PGPort)
	fmt.Printf("  Database: %s\n", cfg.Bastion.PGDatabase)
	fmt.Printf("  Username: %s\n", proxyUser)
	fmt.Printf("  Password: <credencial do operador no Warpgate>\n")
	fmt.Printf("  SSL:      require\n")
	fmt.Printf("\n%s\n", psql)
	if clipboard {
		if err := util.CopyClipboard(psql + "\n"); err != nil {
			fmt.Fprintf(os.Stderr, "warn: clipboard: %v\n", err)
		} else {
			fmt.Println("(copiado para o clipboard)")
		}
	}
	return nil
}

func cmdOpen(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: archgate open <target>")
	}
	target := args[0]
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	b, err := loadBootstrap(cfg)
	if err != nil {
		return err
	}
	conn, err := findConn(b.Connections, target)
	if err != nil {
		return err
	}
	var url string
	switch {
	case conn.Engine == "guacamole":
		url = strings.TrimRight(cfg.Bastion.GuacBase, "/") + "/"
	case conn.Protocol == "http":
		url = fmt.Sprintf("%s/?warpgate-target=%s", strings.TrimRight(cfg.Bastion.HTTPBase, "/"), conn.Target)
	case conn.Protocol == "oracle" || strings.Contains(strings.ToLower(conn.Target), "oracle"):
		url = cfg.Bastion.OracleUI
	default:
		url = strings.TrimRight(cfg.Bastion.ConsoleBase, "/") + "/sites"
	}
	fmt.Printf("→ open %s\n", url)
	return util.OpenBrowser(url)
}

func cmdConfig(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: archgate config apply|remove")
	}
	switch args[0] {
	case "apply":
		cfg, err := config.Load()
		if err != nil {
			return err
		}
		b, err := loadBootstrap(cfg)
		if err != nil {
			return err
		}
		user, err := resolveWarpgateUser(cfg)
		if err != nil {
			return err
		}
		path, err := sshcfg.Apply(cfg.Bastion, user, b.Connections)
		if err != nil {
			fmt.Printf("ssh config: %v\n", err)
			return nil
		}
		fmt.Printf("Wrote managed SSH config: %s\n", path)
		fmt.Println("Hosts: archgate-<target>  (e.g. ssh archgate-rio-aws-api-b)")
		return nil
	case "remove":
		if err := sshcfg.Remove(); err != nil {
			return err
		}
		fmt.Println("Removed managed SSH config (~/.ssh/config.d/archgate)")
		return nil
	default:
		return fmt.Errorf("usage: archgate config apply|remove")
	}
}

func findConn(conns []api.Connection, target string) (*api.Connection, error) {
	for i := range conns {
		if conns[i].Target == target || conns[i].Name == target || conns[i].ID == target {
			return &conns[i], nil
		}
	}
	var hits []api.Connection
	for i := range conns {
		if strings.Contains(conns[i].Target, target) || strings.Contains(conns[i].Name, target) {
			hits = append(hits, conns[i])
		}
	}
	if len(hits) == 1 {
		return &hits[0], nil
	}
	if len(hits) > 1 {
		names := make([]string, len(hits))
		for i, h := range hits {
			names[i] = h.Target
		}
		return nil, fmt.Errorf("ambiguous %q — matches: %s", target, strings.Join(names, ", "))
	}
	return nil, fmt.Errorf("target %q not in catalog — run archgate ls", target)
}
