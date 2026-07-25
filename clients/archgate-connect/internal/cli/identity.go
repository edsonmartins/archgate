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

// cmdWgUser gets or sets credentials.warpgate_user (desktop Onda 1 / F1).
//
//	archgate wg-user              # print resolved user
//	archgate wg-user uat-op-a     # persist
//	archgate wg-user --clear      # remove stored value
func cmdWgUser(args []string, jsonOut bool) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	if len(args) == 0 {
		resolved, rerr := resolveWarpgateUser(cfg)
		stored := cfg.Creds.WarpgateUser
		if jsonOut {
			return printJSON(map[string]any{
				"warpgate_user":        resolved,
				"stored_warpgate_user": stored,
				"env_override":         strings.TrimSpace(os.Getenv("ARCHGATE_WG_USER")) != "",
				"error": func() any {
					if rerr != nil {
						return rerr.Error()
					}
					return nil
				}(),
			})
		}
		if rerr != nil {
			fmt.Printf("warpgate_user: (not set)\n")
			fmt.Printf("hint: archgate wg-user uat-op-a\n")
			return rerr
		}
		fmt.Printf("warpgate_user: %s\n", resolved)
		if stored != "" && stored != resolved {
			fmt.Printf("stored:        %s\n", stored)
		}
		if strings.TrimSpace(os.Getenv("ARCHGATE_WG_USER")) != "" {
			fmt.Printf("source:        ARCHGATE_WG_USER env\n")
		} else if stored != "" {
			fmt.Printf("source:        credentials\n")
		} else {
			fmt.Printf("source:        OIDC username\n")
		}
		return nil
	}
	if args[0] == "--clear" || args[0] == "clear" {
		cfg.Creds.WarpgateUser = ""
		if err := config.SaveCredentials(&cfg.Creds); err != nil {
			return err
		}
		if jsonOut {
			return printJSON(map[string]any{"cleared": true})
		}
		fmt.Println("warpgate_user cleared (will use OIDC username or ARCHGATE_WG_USER)")
		return nil
	}
	name := util.StripAt(strings.TrimSpace(args[0]))
	if name == "" || strings.ContainsAny(name, " \t\n") {
		return fmt.Errorf("invalid warpgate user %q", args[0])
	}
	cfg.Creds.WarpgateUser = name
	if err := config.SaveCredentials(&cfg.Creds); err != nil {
		return err
	}
	if jsonOut {
		return printJSON(map[string]any{"warpgate_user": name, "stored": true})
	}
	fmt.Printf("warpgate_user saved: %s\n", name)
	return nil
}
