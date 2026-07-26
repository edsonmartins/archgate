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
	if act := classifyConn(conn); act != actionDB {
		return fmt.Errorf("target %s is %s/%s — use: archgate go %s (or archgate %s %s)",
			target, conn.Engine, conn.Protocol, target, act, target)
	}
	user, err := resolveWarpgateUser(cfg)
	if err != nil {
		return err
	}
	proxyUser := fmt.Sprintf("%s:%s", user, conn.Target)
	proto := strings.ToLower(conn.Protocol)
	isMySQL := proto == "mysql" || proto == "mariadb"

	if isMySQL {
		host := cfg.Bastion.MySQLHost
		if host == "" {
			host = cfg.Bastion.SSHHost
		}
		port := cfg.Bastion.MySQLPort
		if port <= 0 {
			port = 33306
		}
		// mysql CLI: password interactive (-p). Warpgate uses user=operator:target.
		// --enable-cleartext-plugin is required for Warpgate MySQL auth (mysql_clear_password).
		cmdLine := fmt.Sprintf(
			`mysql -h %s -P %d -u %s -p --ssl-mode=REQUIRED --enable-cleartext-plugin`,
			host, port, proxyUser,
		)
		if jsonOut {
			return printJSON(map[string]any{
				"engine":   "mysql",
				"host":     host,
				"port":     port,
				"username": proxyUser,
				"sslmode":  "REQUIRED",
				"program":  "mysql",
				"args": []string{
					"-h", host,
					"-P", strconv.Itoa(port),
					"-u", proxyUser,
					"-p",
					"--ssl-mode=REQUIRED",
					"--enable-cleartext-plugin",
				},
				"command": cmdLine,
				"mysql":   cmdLine,
				"note":    "Password is your Warpgate/operator credential, not the database password. Bastion must have mysql.enable=true (port 33306). Requires --enable-cleartext-plugin.",
			})
		}
		fmt.Println("MySQL via Warpgate bastion (not target IP)")
		fmt.Printf("  Host:     %s\n", host)
		fmt.Printf("  Port:     %d\n", port)
		fmt.Printf("  Username: %s\n", proxyUser)
		fmt.Printf("  Password: <credencial do operador no Warpgate>\n")
		fmt.Printf("  SSL:      REQUIRED\n")
		fmt.Printf("\n%s\n", cmdLine)
		if clipboard {
			if err := util.CopyClipboard(cmdLine + "\n"); err != nil {
				fmt.Fprintf(os.Stderr, "warn: clipboard: %v\n", err)
			} else {
				fmt.Println("(copiado para o clipboard)")
			}
		}
		return nil
	}

	psql := fmt.Sprintf(`psql "host=%s port=%d user=%s dbname=%s sslmode=require"`,
		cfg.Bastion.PGHost, cfg.Bastion.PGPort, proxyUser, cfg.Bastion.PGDatabase)
	if jsonOut {
		return printJSON(map[string]any{
			"engine":   "postgres",
			"host":     cfg.Bastion.PGHost,
			"port":     cfg.Bastion.PGPort,
			"database": cfg.Bastion.PGDatabase,
			"username": proxyUser,
			"sslmode":  "require",
			"program":  "psql",
			"args":     []string{fmt.Sprintf("host=%s port=%d user=%s dbname=%s sslmode=require", cfg.Bastion.PGHost, cfg.Bastion.PGPort, proxyUser, cfg.Bastion.PGDatabase)},
			"psql":     psql,
			"command":  psql,
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

// managerPathOK allows only relative Manager paths (no scheme/host injection).
func managerPathOK(p string) bool {
	if p == "" || p[0] != '/' {
		return false
	}
	if strings.Contains(p, "//") || strings.Contains(p, "://") || strings.ContainsAny(p, " \t\n\r") {
		return false
	}
	for _, r := range p {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') ||
			(r >= '0' && r <= '9') || r == '/' || r == '-' || r == '_' || r == '.' {
			continue
		}
		return false
	}
	// Reject path traversal segments (e.g. /../x, /sites/..)
	for _, seg := range strings.Split(p, "/") {
		if seg == ".." || seg == "." {
			return false
		}
	}
	return true
}

// cmdManager opens ArchGate Manager (admin control plane) in the system browser.
// Does not pass Connect OIDC tokens. Path is optional and sanitized.
func cmdManager(args []string) error {
	path := "/dashboard"
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--path", "-p":
			if i+1 >= len(args) {
				return fmt.Errorf("usage: archgate manager [--path /sites]")
			}
			path = args[i+1]
			i++
		case "--help", "-h":
			fmt.Println("usage: archgate manager [--path /dashboard|/sites|/gateways|…]")
			return nil
		default:
			// bare path argument
			if strings.HasPrefix(args[i], "/") {
				path = args[i]
			} else {
				return fmt.Errorf("usage: archgate manager [--path /sites]")
			}
		}
	}
	if !managerPathOK(path) {
		return fmt.Errorf("invalid Manager path %q (use e.g. /dashboard, /sites)", path)
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	base := strings.TrimRight(cfg.Bastion.ConsoleBase, "/")
	if base == "" {
		base = "https://console.archgate.com.br"
	}
	url := base + path
	fmt.Printf("→ ArchGate Manager  %s\n", url)
	fmt.Println("(admin control plane — not an operator session)")
	return util.OpenBrowser(url)
}

func openURLForConn(cfg *config.File, conn *api.Connection) string {
	if cfg == nil || conn == nil {
		return ""
	}
	p := strings.ToLower(conn.Protocol)
	switch {
	case conn.Engine == "guacamole" || p == "rdp" || p == "vnc":
		return strings.TrimRight(cfg.Bastion.GuacBase, "/") + "/"
	case p == "http" || p == "https":
		return fmt.Sprintf("%s/?warpgate-target=%s", strings.TrimRight(cfg.Bastion.HTTPBase, "/"), conn.Target)
	case p == "oracle" || strings.Contains(strings.ToLower(conn.Target), "oracle"):
		return cfg.Bastion.OracleUI
	default:
		return strings.TrimRight(cfg.Bastion.ConsoleBase, "/") + "/sites"
	}
}

func cmdPrintOpen(args []string, jsonOut bool) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: archgate print-open <target> [--json]")
	}
	target := args[0]
	if !util.TargetSafe(target) {
		return fmt.Errorf("invalid target %q", target)
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
	url := openURLForConn(cfg, conn)
	if jsonOut {
		return printJSON(map[string]any{
			"url":      url,
			"target":   conn.Target,
			"protocol": conn.Protocol,
			"engine":   conn.Engine,
			"guac_base": cfg.Bastion.GuacBase,
		})
	}
	fmt.Println(url)
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
	url := openURLForConn(cfg, conn)
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
