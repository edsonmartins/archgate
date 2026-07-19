package sshcfg

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/api"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/config"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/util"
)

const managedHeader = "# BEGIN ARCHGATE MANAGED — do not edit by hand (archgate config apply)"
const managedFooter = "# END ARCHGATE MANAGED"

func ManagedPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	dir := filepath.Join(home, ".ssh", "config.d")
	return filepath.Join(dir, "archgate"), nil
}

func Apply(bastion config.Bastion, username string, conns []api.Connection) (string, error) {
	path, err := ManagedPath()
	if err != nil {
		return "", err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return "", err
	}
	var b strings.Builder
	b.WriteString(managedHeader + "\n")
	b.WriteString("# Bastion-only hosts. Never customer private IPs.\n\n")
	for _, c := range conns {
		if c.Engine != "warpgate" || c.Protocol != "ssh" {
			continue
		}
		user := username
		if user == "" {
			user = "SEU_USUARIO"
		}
		proxyUser := fmt.Sprintf("%s:%s", user, c.Target)
		hostAlias := "archgate-" + util.Sanitize(c.Target)
		fmt.Fprintf(&b, "Host %s\n", hostAlias)
		fmt.Fprintf(&b, "  HostName %s\n", bastion.SSHHost)
		fmt.Fprintf(&b, "  Port %d\n", bastion.SSHPort)
		fmt.Fprintf(&b, "  User %s\n", proxyUser)
		b.WriteString("  StrictHostKeyChecking accept-new\n\n")
	}
	b.WriteString(managedFooter + "\n")
	if err := os.WriteFile(path, []byte(b.String()), 0o600); err != nil {
		return "", err
	}
	if err := ensureInclude(path); err != nil {
		return path, fmt.Errorf("wrote %s but Include failed: %w", path, err)
	}
	return path, nil
}

func Remove() error {
	path, err := ManagedPath()
	if err != nil {
		return err
	}
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

func ensureInclude(managedPath string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	main := filepath.Join(home, ".ssh", "config")
	includeLine := "Include config.d/archgate"
	_ = managedPath
	data, err := os.ReadFile(main)
	if err != nil {
		if os.IsNotExist(err) {
			content := includeLine + "\n"
			if err := os.MkdirAll(filepath.Dir(main), 0o700); err != nil {
				return err
			}
			return os.WriteFile(main, []byte(content), 0o600)
		}
		return err
	}
	if strings.Contains(string(data), "config.d/archgate") {
		return nil
	}
	out := includeLine + "\n" + string(data)
	return os.WriteFile(main, []byte(out), 0o600)
}
