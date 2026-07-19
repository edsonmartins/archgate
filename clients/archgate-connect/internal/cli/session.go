package cli

import (
	"errors"
	"fmt"
	"os"
	"time"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/api"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/config"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/oidc"
)

// ErrNeedLogin is returned when the operator must run archgate login (SSO) again.
var ErrNeedLogin = errors.New("session expired — run: archgate login")

const accessTokenSkew = 60 * time.Second

// ensureAPIToken refreshes the OIDC access token when expired/near-expiry.
// Lab sessions are a no-op. On hard failure, credentials may be cleared.
func ensureAPIToken(cfg *config.File) error {
	if cfg == nil {
		return fmt.Errorf("nil config")
	}
	// Lab catalog token — no OIDC refresh.
	if cfg.Creds.IsLabSession() {
		return nil
	}
	if !cfg.Creds.HasOIDCSession() {
		return fmt.Errorf("%w (not logged in)", ErrNeedLogin)
	}
	if cfg.Creds.AccessToken != "" && !cfg.Creds.AccessTokenExpired(accessTokenSkew) {
		return nil
	}
	// Access missing or near expiry → refresh.
	if cfg.Creds.RefreshToken == "" {
		_ = config.ClearCredentials()
		return fmt.Errorf("%w (no refresh_token)", ErrNeedLogin)
	}
	if err := refreshAndSave(cfg); err != nil {
		_ = config.ClearCredentials()
		return fmt.Errorf("%w (%v)", ErrNeedLogin, err)
	}
	return nil
}

func refreshAndSave(cfg *config.File) error {
	ocfg := oidc.DefaultConfig()
	tok, err := oidc.Refresh(ocfg, cfg.Creds.RefreshToken)
	if err != nil {
		return err
	}
	applyTokenToCreds(&cfg.Creds, tok)
	if err := config.SaveCredentials(&cfg.Creds); err != nil {
		return err
	}
	fmt.Fprintf(os.Stderr, "archgate: OIDC access token refreshed (expires_at=%d)\n", cfg.Creds.ExpiresAt)
	return nil
}

func applyTokenToCreds(c *config.Credentials, tok *oidc.TokenResponse) {
	if c == nil || tok == nil {
		return
	}
	c.AccessToken = tok.AccessToken
	if tok.RefreshToken != "" {
		c.RefreshToken = tok.RefreshToken
	}
	if exp := oidc.ExpiresAtUnix(tok, time.Now()); exp > 0 {
		c.ExpiresAt = exp
	}
	// Clear lab placeholder if we now have real OIDC.
	c.LabToken = ""
}

// withAuthRetry runs fn after ensureAPIToken; on 401 refreshes once and retries.
func withAuthRetry(cfg *config.File, fn func(*config.File) error) error {
	if err := ensureAPIToken(cfg); err != nil {
		return err
	}
	err := fn(cfg)
	if err == nil || !api.IsUnauthorized(err) {
		return err
	}
	// One forced refresh after 401 (even if ExpiresAt looked fine).
	if cfg.Creds.RefreshToken == "" {
		_ = config.ClearCredentials()
		return fmt.Errorf("%w: %v", ErrNeedLogin, err)
	}
	if rerr := refreshAndSave(cfg); rerr != nil {
		_ = config.ClearCredentials()
		return fmt.Errorf("%w (%v; after 401: %v)", ErrNeedLogin, rerr, err)
	}
	err = fn(cfg)
	if api.IsUnauthorized(err) {
		_ = config.ClearCredentials()
		return fmt.Errorf("%w: %v", ErrNeedLogin, err)
	}
	return err
}

func needLoginHint(err error) string {
	if err == nil {
		return ""
	}
	if errors.Is(err, ErrNeedLogin) || api.IsUnauthorized(err) {
		return "\nHint: archgate login   # SSO browser\n      archgate login --lab --user YOU   # homolog only"
	}
	return ""
}
