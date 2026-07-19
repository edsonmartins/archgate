package oidc

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

func TestRefreshSuccess(t *testing.T) {
	var gotForm url.Values
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/.well-known/openid-configuration") {
			_ = json.NewEncoder(w).Encode(map[string]string{
				"issuer":                 "http://example",
				"authorization_endpoint": "http://example/auth",
				"token_endpoint":         "http://" + r.Host + "/token",
				"userinfo_endpoint":      "http://" + r.Host + "/userinfo",
			})
			return
		}
		if r.URL.Path == "/token" {
			b, _ := io.ReadAll(r.Body)
			gotForm, _ = url.ParseQuery(string(b))
			_ = json.NewEncoder(w).Encode(TokenResponse{
				AccessToken:  "new-access",
				RefreshToken: "new-refresh",
				ExpiresIn:    3600,
				TokenType:    "Bearer",
			})
			return
		}
		http.NotFound(w, r)
	}))
	defer srv.Close()

	tok, err := Refresh(Config{
		IssuerBase:   srv.URL,
		ClientID:     "archgate-connect",
		ClientSecret: "s3cret",
		Scopes:       "openid profile",
	}, "old-refresh")
	if err != nil {
		t.Fatal(err)
	}
	if tok.AccessToken != "new-access" {
		t.Fatalf("access=%q", tok.AccessToken)
	}
	if tok.RefreshToken != "new-refresh" {
		t.Fatalf("refresh=%q", tok.RefreshToken)
	}
	if gotForm.Get("grant_type") != "refresh_token" {
		t.Fatalf("grant=%q", gotForm.Get("grant_type"))
	}
	if gotForm.Get("refresh_token") != "old-refresh" {
		t.Fatalf("rt=%q", gotForm.Get("refresh_token"))
	}
	if gotForm.Get("client_secret") != "s3cret" {
		t.Fatalf("secret missing")
	}
	exp := ExpiresAtUnix(tok, time.Unix(1_700_000_000, 0))
	if exp != 1_700_000_000+3600 {
		t.Fatalf("exp=%d", exp)
	}
}

func TestRefreshRejectsEmpty(t *testing.T) {
	if _, err := Refresh(DefaultConfig(), ""); err == nil {
		t.Fatal("expected error")
	}
}

func TestRefreshHTTPError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/.well-known/openid-configuration") {
			_ = json.NewEncoder(w).Encode(map[string]string{
				"token_endpoint": "http://" + r.Host + "/token",
			})
			return
		}
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":"invalid_grant"}`))
	}))
	defer srv.Close()
	_, err := Refresh(Config{IssuerBase: srv.URL, ClientID: "c"}, "bad")
	if err == nil {
		t.Fatal("expected error")
	}
	if !strings.Contains(err.Error(), "400") && !strings.Contains(err.Error(), "invalid_grant") {
		t.Fatalf("err=%v", err)
	}
}
