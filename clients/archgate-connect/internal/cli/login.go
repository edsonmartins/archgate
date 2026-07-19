package cli

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/config"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/oidc"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/util"
)

func cmdLogin(args []string) error {
	fmt.Println("ArchGate Connect — Bastion, not VPN")
	lab := false
	user := "lab.operator"
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--lab":
			lab = true
		case "--user":
			if i+1 < len(args) {
				user = args[i+1]
				i++
			}
		case "--oidc":
			// default path
		}
	}
	if lab || os.Getenv("ARCHGATE_LOGIN_LAB") == "1" {
		return loginLab(user)
	}
	return loginOIDC()
}

func loginLab(user string) error {
	wgUser := labWarpgateUser()
	c := &config.Credentials{
		Username:     user,
		LabToken:     "lab-" + user,
		WarpgateUser: wgUser,
	}
	if err := config.SaveCredentials(c); err != nil {
		return err
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	if err := config.Save(cfg); err != nil {
		return err
	}
	if !config.MockMode() {
		if b, err := loadBootstrap(cfg); err == nil {
			fmt.Printf("Logged in as %s (lab catalog). Warpgate SSH user: %s · %d connections.\n",
				user, wgUser, len(b.Connections))
			fmt.Println("SSH: archgate ssh <target>")
			fmt.Printf("Note: password is Warpgate user (%s), not the lab catalog nickname.\n", wgUser)
			return nil
		} else {
			fmt.Printf("Logged in as %s (lab). Warpgate SSH user: %s\n", user, wgUser)
			fmt.Fprintf(os.Stderr, "warn: catalog bootstrap: %v\n", err)
			return nil
		}
	}
	fmt.Printf("Logged in as %s (lab). Warpgate SSH user: %s\n", user, wgUser)
	return nil
}

func loginOIDC() error {
	ocfg := oidc.DefaultConfig()
	tok, ui, err := oidc.LoginBrowser(ocfg)
	if err != nil {
		return fmt.Errorf("OIDC login failed: %w\nHint: source ~/.config/archgate/oidc.env  or  archgate login --lab", err)
	}
	username := ui.PreferredUsername
	if username == "" {
		username = ui.Name
	}
	if username == "" {
		username = ui.Email
	}
	if username == "" {
		username = "operator"
	}
	creds := &config.Credentials{
		Username: username,
		// OIDC: Warpgate user defaults to preferred username; override via env.
		WarpgateUser: util.Or(strings.TrimSpace(os.Getenv("ARCHGATE_WG_USER")), username),
	}
	applyTokenToCreds(creds, tok)
	if err := config.SaveCredentials(creds); err != nil {
		return err
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	if err := config.Save(cfg); err != nil {
		return err
	}
	n := 0
	if b, err := loadBootstrap(cfg); err == nil {
		n = len(b.Connections)
		_ = config.Save(cfg)
	} else {
		fmt.Fprintf(os.Stderr, "warn: catalog bootstrap: %v\n", err)
	}
	expNote := ""
	if creds.ExpiresAt > 0 {
		expNote = fmt.Sprintf(" · token até %s", time.Unix(creds.ExpiresAt, 0).Local().Format(time.RFC3339))
	}
	fmt.Printf("Logged in as %s (OIDC). Warpgate user: %s · %d connections%s\n",
		username, creds.WarpgateUser, n, expNote)
	return nil
}

func cmdLogout() error {
	if err := config.ClearCredentials(); err != nil {
		return err
	}
	fmt.Println("Logged out.")
	return nil
}
