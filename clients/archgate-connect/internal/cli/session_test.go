package cli

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/api"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/config"
	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/oidc"
)

func TestApplyTokenToCreds(t *testing.T) {
	c := &config.Credentials{LabToken: "lab-x", RefreshToken: "old"}
	applyTokenToCreds(c, &oidc.TokenResponse{
		AccessToken:  "a1",
		RefreshToken: "",
		ExpiresIn:    120,
	})
	if c.AccessToken != "a1" {
		t.Fatal(c.AccessToken)
	}
	if c.RefreshToken != "old" {
		t.Fatal("should keep old refresh when omitted")
	}
	if c.LabToken != "" {
		t.Fatal("lab token should clear on OIDC")
	}
	if c.ExpiresAt == 0 {
		t.Fatal("expires_at expected")
	}
}

func TestEnsureAPITokenLabNoop(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_MOCK", "1")
	cfg := &config.File{Creds: config.Credentials{LabToken: "lab-u", Username: "u"}}
	if err := ensureAPIToken(cfg); err != nil {
		t.Fatal(err)
	}
}

func TestEnsureAPITokenRefreshesExpired(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_MOCK", "0")

	var nToken int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/.well-known/openid-configuration") {
			_ = json.NewEncoder(w).Encode(map[string]string{
				"token_endpoint": "http://" + r.Host + "/token",
			})
			return
		}
		if r.URL.Path == "/token" {
			nToken++
			_ = json.NewEncoder(w).Encode(oidc.TokenResponse{
				AccessToken:  "fresh",
				RefreshToken: "rt2",
				ExpiresIn:    3600,
			})
			return
		}
		http.NotFound(w, r)
	}))
	defer srv.Close()
	t.Setenv("ARCHGATE_OIDC_ISSUER", srv.URL)
	t.Setenv("ARCHGATE_OIDC_CLIENT_ID", "archgate-connect")
	t.Setenv("ARCHGATE_OIDC_CLIENT_SECRET", "")

	cfg := &config.File{
		Creds: config.Credentials{
			AccessToken:  "stale",
			RefreshToken: "rt1",
			ExpiresAt:    time.Now().Add(-time.Minute).Unix(),
			Username:     "op",
		},
	}
	if err := ensureAPIToken(cfg); err != nil {
		t.Fatal(err)
	}
	if cfg.Creds.AccessToken != "fresh" {
		t.Fatalf("access=%q", cfg.Creds.AccessToken)
	}
	if nToken != 1 {
		t.Fatalf("token calls=%d", nToken)
	}
	loaded, err := config.LoadCredentials()
	if err != nil {
		t.Fatal(err)
	}
	if loaded.AccessToken != "fresh" {
		t.Fatalf("disk access=%q", loaded.AccessToken)
	}
}

func TestEnsureAPITokenNoRefreshClears(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	// Pre-create credentials file to ensure ClearCredentials removes it.
	if err := config.SaveCredentials(&config.Credentials{
		AccessToken: "x",
		ExpiresAt:   time.Now().Add(-time.Hour).Unix(),
	}); err != nil {
		t.Fatal(err)
	}
	cfg := &config.File{
		Creds: config.Credentials{
			AccessToken: "x",
			ExpiresAt:   time.Now().Add(-time.Hour).Unix(),
		},
	}
	err := ensureAPIToken(cfg)
	if err == nil {
		t.Fatal("expected need login")
	}
	if !strings.Contains(err.Error(), "session expired") {
		t.Fatalf("err=%v", err)
	}
	if _, err := os.Stat(filepath.Join(dir, "credentials.json")); !os.IsNotExist(err) {
		t.Fatalf("credentials should be cleared, err=%v", err)
	}
}

func TestWithAuthRetryOn401(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_MOCK", "0")

	var tokenHits, apiHits int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/.well-known/openid-configuration") {
			_ = json.NewEncoder(w).Encode(map[string]string{
				"token_endpoint": "http://" + r.Host + "/token",
			})
			return
		}
		if r.URL.Path == "/token" {
			tokenHits++
			_ = json.NewEncoder(w).Encode(oidc.TokenResponse{
				AccessToken: "after-401",
				ExpiresIn:   3600,
			})
			return
		}
		http.NotFound(w, r)
	}))
	defer srv.Close()
	t.Setenv("ARCHGATE_OIDC_ISSUER", srv.URL)

	cfg := &config.File{
		Creds: config.Credentials{
			AccessToken:  "still-valid-looking",
			RefreshToken: "rt",
			ExpiresAt:    time.Now().Add(time.Hour).Unix(),
			Username:     "op",
		},
	}
	err := withAuthRetry(cfg, func(cfg *config.File) error {
		apiHits++
		if apiHits == 1 {
			return &api.StatusError{Op: "bootstrap", Status: 401, Body: "unauthorized"}
		}
		if cfg.Creds.AccessToken != "after-401" {
			t.Fatalf("expected refreshed token before retry, got %q", cfg.Creds.AccessToken)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if tokenHits != 1 || apiHits != 2 {
		t.Fatalf("tokenHits=%d apiHits=%d", tokenHits, apiHits)
	}
}

func TestAccessTokenExpiredHelpers(t *testing.T) {
	c := config.Credentials{AccessToken: "a", ExpiresAt: time.Now().Add(time.Hour).Unix()}
	if c.AccessTokenExpired(0) {
		t.Fatal("should be valid")
	}
	c.ExpiresAt = time.Now().Add(-time.Second).Unix()
	if !c.AccessTokenExpired(0) {
		t.Fatal("should be expired")
	}
	c2 := config.Credentials{AccessToken: "a", ExpiresAt: 0}
	if c2.AccessTokenExpired(time.Minute) {
		t.Fatal("unknown expiry should not proactive-expire")
	}
}
