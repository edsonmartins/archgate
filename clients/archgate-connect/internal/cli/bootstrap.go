package cli

import (
	"fmt"
	"os"
	"strings"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/api"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/config"
)

func loadBootstrap(cfg *config.File) (*api.Bootstrap, error) {
	if config.MockMode() {
		return api.MockBootstrap(cfg), nil
	}
	client := api.New(cfg)
	b, err := client.Bootstrap()
	if err != nil {
		if os.Getenv("ARCHGATE_MOCK_FALLBACK") == "1" {
			fmt.Fprintf(os.Stderr, "warn: API bootstrap failed (%v); using mock\n", err)
			return api.MockBootstrap(cfg), nil
		}
		return nil, err
	}
	if b.Bastion.SSHHost != "" {
		cfg.Bastion = b.Bastion
		// Cloudflare only publishes HTTPS for wg.*; TCP SSH/PG are on the VPS IP.
		if isCloudflareOnlyHost(cfg.Bastion.SSHHost) {
			cfg.Bastion.SSHHost = config.DefaultBastion().SSHHost
		}
		if isCloudflareOnlyHost(cfg.Bastion.PGHost) {
			cfg.Bastion.PGHost = config.DefaultBastion().PGHost
		}
		_ = config.Save(cfg)
	}
	if b.Profile.Username != "" && cfg.Creds.Username == "" {
		cfg.Creds.Username = b.Profile.Username
	}
	return b, nil
}

func isCloudflareOnlyHost(h string) bool {
	h = strings.ToLower(strings.TrimSpace(h))
	if h == "wg.archgate.com.br" {
		return true
	}
	return strings.HasPrefix(h, "wg.") && strings.HasSuffix(h, ".archgate.com.br")
}
