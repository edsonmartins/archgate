package cli

import (
	"fmt"
	"os"
	"strings"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/config"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/util"
)

// defaultLabWarpgateUser is stored on lab login when ARCHGATE_WG_USER is unset.
// It is never inferred from catalog nicknames (lab.operator, edson, …).
const defaultLabWarpgateUser = "uat-op-a"

// resolveWarpgateUser returns the Warpgate login name for bastion SSH/DB.
//
// Precedence:
//  1. ARCHGATE_WG_USER
//  2. credentials.warpgate_user (set by login --lab or explicit config)
//  3. OIDC session: credentials.username (operator account maps 1:1)
//
// Catalog / lab nicknames are never used as Warpgate identity.
func resolveWarpgateUser(cfg *config.File) (string, error) {
	if v := strings.TrimSpace(os.Getenv("ARCHGATE_WG_USER")); v != "" {
		return util.StripAt(v), nil
	}
	if cfg.Creds.WarpgateUser != "" {
		return util.StripAt(cfg.Creds.WarpgateUser), nil
	}
	// OIDC: preferred username is the operator account when no explicit WG user.
	if cfg.Creds.AccessToken != "" && cfg.Creds.Username != "" {
		return util.StripAt(cfg.Creds.Username), nil
	}
	return "", fmt.Errorf(
		"warpgate user not set — export ARCHGATE_WG_USER or run: archgate login --lab (stores warpgate_user=%s)",
		defaultLabWarpgateUser,
	)
}

// labWarpgateUser is the value written into credentials on lab login.
func labWarpgateUser() string {
	if v := strings.TrimSpace(os.Getenv("ARCHGATE_WG_USER")); v != "" {
		return util.StripAt(v)
	}
	return defaultLabWarpgateUser
}
