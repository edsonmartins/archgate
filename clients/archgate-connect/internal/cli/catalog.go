package cli

import (
	"fmt"
	"net"
	"os/exec"
	"strconv"
	"time"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/config"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/util"
)

func cmdStatus(jsonOut bool) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	logged := cfg.Creds.LabToken != "" || cfg.Creds.AccessToken != ""
	mode := "none"
	if cfg.Creds.AccessToken != "" {
		mode = "oidc"
	} else if cfg.Creds.LabToken != "" {
		mode = "lab"
	}
	wgUser := ""
	if logged {
		if u, err := resolveWarpgateUser(cfg); err == nil {
			wgUser = u
		}
	}
	out := map[string]any{
		"version":       version,
		"api_base":      cfg.APIBase,
		"mock":          config.MockMode(),
		"user":          util.Or(cfg.Creds.Username, ""),
		"warpgate_user": wgUser,
		"session":       logged,
		"auth":          mode,
		"bastion": map[string]any{
			"ssh_host": cfg.Bastion.SSHHost,
			"ssh_port": cfg.Bastion.SSHPort,
			"pg_host":  cfg.Bastion.PGHost,
			"pg_port":  cfg.Bastion.PGPort,
		},
	}
	if logged && !config.MockMode() {
		if b, err := loadBootstrap(cfg); err == nil {
			out["connections"] = len(b.Connections)
			out["tenants"] = b.Profile.Tenants
		}
	}
	if jsonOut {
		return printJSON(out)
	}
	fmt.Printf("api_base:     %s\n", cfg.APIBase)
	fmt.Printf("mock:         %v\n", config.MockMode())
	fmt.Printf("user:         %s\n", util.Or(cfg.Creds.Username, "(not logged in)"))
	fmt.Printf("session:      %v (%s)\n", logged, mode)
	if wgUser != "" {
		fmt.Printf("warpgate:     %s\n", wgUser)
	}
	fmt.Printf("ssh bastion:  %s:%d\n", cfg.Bastion.SSHHost, cfg.Bastion.SSHPort)
	fmt.Printf("pg bastion:   %s:%d\n", cfg.Bastion.PGHost, cfg.Bastion.PGPort)
	if n, ok := out["connections"].(int); ok {
		fmt.Printf("connections:  %d\n", n)
	}
	return nil
}

func cmdLs(jsonOut bool) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	b, err := loadBootstrap(cfg)
	if err != nil {
		return err
	}
	if jsonOut {
		return printJSON(map[string]any{
			"user":        util.Or(b.Profile.Username, cfg.Creds.Username),
			"tenants":     b.Profile.Tenants,
			"bastion":     b.Bastion,
			"connections": b.Connections,
		})
	}
	if len(b.Connections) == 0 {
		fmt.Println("(no connections — check tenant roles / site inventariado)")
		return nil
	}
	fmt.Printf("%-22s %-10s %-10s %-22s %s\n", "TARGET", "PROTO", "ENGINE", "SITE", "ID")
	for _, c := range b.Connections {
		fmt.Printf("%-22s %-10s %-10s %-22s %s\n", c.Target, c.Protocol, c.Engine, util.Trunc(c.Site, 22), c.ID)
	}
	fmt.Printf("\n%d connections · user %s\n", len(b.Connections), util.Or(b.Profile.Username, cfg.Creds.Username))
	fmt.Println("Connect: archgate ssh <target>   |   archgate config apply")
	return nil
}

func cmdDoctor(jsonOut bool) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	type check struct {
		Name   string `json:"name"`
		OK     bool   `json:"ok"`
		Detail string `json:"detail"`
	}
	var checks []check
	logged := cfg.Creds.LabToken != "" || cfg.Creds.AccessToken != ""
	checks = append(checks, check{"auth", logged, util.Or(cfg.Creds.Username, "not logged in")})
	if logged {
		if u, err := resolveWarpgateUser(cfg); err == nil {
			checks = append(checks, check{"warpgate_user", true, u})
		} else {
			checks = append(checks, check{"warpgate_user", false, err.Error()})
		}
	}
	sshOK, sshD := tcpCheck(cfg.Bastion.SSHHost, cfg.Bastion.SSHPort)
	checks = append(checks, check{"ssh_bastion", sshOK, sshD})
	pgOK, pgD := tcpCheck(cfg.Bastion.PGHost, cfg.Bastion.PGPort)
	checks = append(checks, check{"pg_bastion", pgOK, pgD})
	_, errSSH := exec.LookPath("ssh")
	checks = append(checks, check{"openssh_cli", errSSH == nil, map[bool]string{true: "on PATH", false: "MISSING"}[errSSH == nil]})
	if logged && !config.MockMode() {
		if b, err := loadBootstrap(cfg); err == nil {
			checks = append(checks, check{"catalog", true, fmt.Sprintf("%d connections", len(b.Connections))})
		} else {
			checks = append(checks, check{"catalog", false, err.Error()})
		}
	}
	if jsonOut {
		return printJSON(map[string]any{"version": version, "checks": checks})
	}
	fmt.Println("ArchGate Connect doctor")
	fmt.Printf("  version: %s\n", version)
	fmt.Printf("  mock:    %v\n", config.MockMode())
	for _, c := range checks {
		mark := "OK"
		if !c.OK {
			mark = "FAIL"
		}
		fmt.Printf("  %-14s %s  %s\n", c.Name+":", mark, c.Detail)
	}
	fmt.Println("  urls:")
	for _, u := range []string{cfg.Bastion.ConsoleBase, cfg.Bastion.HTTPBase, cfg.Bastion.GuacBase} {
		fmt.Printf("    %s\n", u)
	}
	return nil
}

func tcpCheck(host string, port int) (bool, string) {
	addr := net.JoinHostPort(host, strconv.Itoa(port))
	conn, err := net.DialTimeout("tcp", addr, 3*time.Second)
	if err != nil {
		return false, addr + " " + err.Error()
	}
	_ = conn.Close()
	return true, addr + " OPEN"
}
