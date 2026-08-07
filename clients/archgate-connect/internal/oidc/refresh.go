package oidc

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// Refresh exchanges a refresh_token for a new access (and possibly refresh) token.
func Refresh(cfg Config, refreshToken string) (*TokenResponse, error) {
	refreshToken = strings.TrimSpace(refreshToken)
	if refreshToken == "" {
		return nil, fmt.Errorf("empty refresh_token")
	}
	disc, err := Discover(cfg.IssuerBase)
	if err != nil {
		return nil, fmt.Errorf("OIDC discovery: %w", err)
	}
	if disc.TokenEndpoint == "" {
		return nil, fmt.Errorf("token_endpoint missing from discovery")
	}
	form := url.Values{}
	form.Set("grant_type", "refresh_token")
	form.Set("refresh_token", refreshToken)
	form.Set("client_id", cfg.ClientID)
	if cfg.ClientSecret != "" {
		form.Set("client_secret", cfg.ClientSecret)
	}
	// Some ASs require scope on refresh; harmless if ignored.
	if cfg.Scopes != "" {
		form.Set("scope", cfg.Scopes)
	}

	req, err := http.NewRequest(http.MethodPost, disc.TokenEndpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")

	client := &http.Client{Timeout: 20 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(res.Body)
	if res.StatusCode >= 300 {
		return nil, fmt.Errorf("refresh token %s: %s", res.Status, string(body))
	}
	var tok TokenResponse
	if err := json.Unmarshal(body, &tok); err != nil {
		return nil, err
	}
	if tok.AccessToken == "" {
		return nil, fmt.Errorf("refresh returned empty access_token")
	}
	// Providers may omit refresh_token on refresh — keep the previous token.
	return &tok, nil
}

// ExpiresAtUnix returns now+expires_in (or 0 if expires_in is missing/zero).
func ExpiresAtUnix(tok *TokenResponse, now time.Time) int64 {
	if tok == nil || tok.ExpiresIn <= 0 {
		return 0
	}
	return now.Add(time.Duration(tok.ExpiresIn) * time.Second).Unix()
}
