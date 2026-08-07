// Package oidc implements authorization_code + PKCE against ArchGuard.
package oidc

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/util"
)

type Discovery struct {
	Issuer                string `json:"issuer"`
	AuthorizationEndpoint string `json:"authorization_endpoint"`
	TokenEndpoint         string `json:"token_endpoint"`
	UserinfoEndpoint      string `json:"userinfo_endpoint"`
}

type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	IDToken      string `json:"id_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
}

type UserInfo struct {
	Sub               string   `json:"sub"`
	PreferredUsername string   `json:"preferred_username"`
	Name              string   `json:"name"`
	Email             string   `json:"email"`
	Groups            []string `json:"groups"`
}

type Config struct {
	IssuerBase       string // ArchGuard discovery root
	ClientID         string
	ClientSecret     string // optional; confidential clients need client_secret_post
	CallbackHostPort string // 127.0.0.1:8765
	Scopes           string
}

// defaultIssuerBase resolves the ArchGuard deployment issuer. Endpoint URLs
// are always obtained from discovery; consumers never encode provider-specific
// paths.
func defaultIssuerBase() string {
	return env("ARCHGATE_IDP_URL", "https://app.archguard.com.br")
}

func DefaultConfig() Config {
	return Config{
		IssuerBase:       env("ARCHGATE_OIDC_ISSUER", defaultIssuerBase()),
		ClientID:         env("ARCHGATE_OIDC_CLIENT_ID", "archgate-connect"),
		ClientSecret:     env("ARCHGATE_OIDC_CLIENT_SECRET", ""),
		CallbackHostPort: env("ARCHGATE_OIDC_CALLBACK", "127.0.0.1:8765"),
		Scopes:           env("ARCHGATE_OIDC_SCOPES", "openid profile email groups"),
	}
}

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func Discover(issuerBase string) (*Discovery, error) {
	u := strings.TrimRight(issuerBase, "/") + "/.well-known/openid-configuration"
	res, err := http.Get(u)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode >= 300 {
		b, _ := io.ReadAll(res.Body)
		return nil, fmt.Errorf("discovery %s: %s", res.Status, string(b))
	}
	var d Discovery
	if err := json.NewDecoder(res.Body).Decode(&d); err != nil {
		return nil, err
	}
	return &d, nil
}

func randomB64(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func pkcePair() (verifier, challenge string, err error) {
	verifier, err = randomB64(32)
	if err != nil {
		return "", "", err
	}
	sum := sha256.Sum256([]byte(verifier))
	challenge = base64.RawURLEncoding.EncodeToString(sum[:])
	return verifier, challenge, nil
}

// LoginBrowser opens the system browser, runs a localhost callback, exchanges code.
func LoginBrowser(cfg Config) (*TokenResponse, *UserInfo, error) {
	disc, err := Discover(cfg.IssuerBase)
	if err != nil {
		return nil, nil, fmt.Errorf("OIDC discovery: %w (register client archgate-connect?)", err)
	}
	verifier, challenge, err := pkcePair()
	if err != nil {
		return nil, nil, err
	}
	state, err := randomB64(16)
	if err != nil {
		return nil, nil, err
	}
	redirectURI := "http://" + cfg.CallbackHostPort + "/callback"

	ln, err := net.Listen("tcp", cfg.CallbackHostPort)
	if err != nil {
		return nil, nil, fmt.Errorf("listen callback %s: %w", cfg.CallbackHostPort, err)
	}

	codeCh := make(chan string, 1)
	errCh := make(chan error, 1)
	mux := http.NewServeMux()
	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("error") != "" {
			errCh <- fmt.Errorf("oidc error: %s (%s)", r.URL.Query().Get("error"), r.URL.Query().Get("error_description"))
			fmt.Fprint(w, "Login failed. You can close this window.")
			return
		}
		if r.URL.Query().Get("state") != state {
			errCh <- fmt.Errorf("state mismatch")
			fmt.Fprint(w, "State mismatch.")
			return
		}
		code := r.URL.Query().Get("code")
		if code == "" {
			errCh <- fmt.Errorf("missing code")
			fmt.Fprint(w, "Missing code.")
			return
		}
		fmt.Fprint(w, "<html><body><h2>ArchGate Connect</h2><p>Login OK — pode fechar esta janela.</p></body></html>")
		codeCh <- code
	})
	srv := &http.Server{Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	go func() { _ = srv.Serve(ln) }()
	defer func() {
		_ = srv.Close()
		_ = ln.Close()
	}()

	q := url.Values{}
	q.Set("response_type", "code")
	q.Set("client_id", cfg.ClientID)
	q.Set("redirect_uri", redirectURI)
	q.Set("scope", cfg.Scopes)
	q.Set("state", state)
	q.Set("code_challenge", challenge)
	q.Set("code_challenge_method", "S256")
	authURL := disc.AuthorizationEndpoint + "?" + q.Encode()

	fmt.Println("Abrindo browser para login ArchGuard…")
	fmt.Println(authURL)
	fmt.Println()
	fmt.Println("Importante:")
	fmt.Println("  1) Use a URL acima (não abra id.archgate.com.br sozinho).")
	fmt.Println("  2) Após digitar a senha, se aparecer 'Allow/Permitir' para ArchGate Connect, aceite.")
	fmt.Println("  3) O browser deve ir para http://127.0.0.1:8765/callback — deixe esta janela/terminal aberta.")
	fmt.Println("  4) Se o ArchGuard não redirecionar, cancele (Ctrl+C) e rode novamente: archgate login")
	fmt.Println()
	_ = util.OpenBrowser(authURL)

	var code string
	select {
	case code = <-codeCh:
	case err = <-errCh:
		return nil, nil, err
	case <-time.After(5 * time.Minute):
		return nil, nil, fmt.Errorf("login timeout (5m): callback em http://%s/callback não chegou — o CLI precisa continuar rodando até o redirect", cfg.CallbackHostPort)
	}

	tok, err := exchangeCode(disc.TokenEndpoint, cfg.ClientID, cfg.ClientSecret, code, redirectURI, verifier)
	if err != nil {
		return nil, nil, err
	}
	ui, err := FetchUserInfo(disc.UserinfoEndpoint, tok.AccessToken)
	if err != nil {
		// non-fatal profile
		ui = &UserInfo{}
	}
	return tok, ui, nil
}

func exchangeCode(tokenURL, clientID, clientSecret, code, redirectURI, verifier string) (*TokenResponse, error) {
	// Prefer confidential-client authentication through HTTP Basic.
	// Fall back to client_secret_post if Basic is rejected.
	try := func(useBasic bool) (*TokenResponse, int, string, error) {
		form := url.Values{}
		form.Set("grant_type", "authorization_code")
		form.Set("code", code)
		form.Set("redirect_uri", redirectURI)
		form.Set("code_verifier", verifier)
		if !useBasic {
			form.Set("client_id", clientID)
			if clientSecret != "" {
				form.Set("client_secret", clientSecret)
			}
		} else {
			// Some ASs still want client_id in body with Basic.
			form.Set("client_id", clientID)
		}
		req, err := http.NewRequest(http.MethodPost, tokenURL, strings.NewReader(form.Encode()))
		if err != nil {
			return nil, 0, "", err
		}
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		req.Header.Set("Accept", "application/json")
		if useBasic && clientSecret != "" {
			req.SetBasicAuth(clientID, clientSecret)
		}
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			return nil, 0, "", err
		}
		defer res.Body.Close()
		body, _ := io.ReadAll(res.Body)
		if res.StatusCode >= 300 {
			return nil, res.StatusCode, string(body), nil
		}
		var tok TokenResponse
		if err := json.Unmarshal(body, &tok); err != nil {
			return nil, res.StatusCode, string(body), err
		}
		if tok.AccessToken == "" {
			return nil, res.StatusCode, string(body), fmt.Errorf("empty access_token")
		}
		return &tok, res.StatusCode, string(body), nil
	}

	if clientSecret != "" {
		if tok, status, body, err := try(true); err != nil {
			return nil, err
		} else if tok != nil {
			return tok, nil
		} else if status != 401 && status != 403 {
			return nil, fmt.Errorf("token %d: %s", status, body)
		}
		// retry post body style
		if tok, status, body, err := try(false); err != nil {
			return nil, err
		} else if tok != nil {
			return tok, nil
		} else {
			return nil, fmt.Errorf("token %d: %s", status, body)
		}
	}

	tok, status, body, err := try(false)
	if err != nil {
		return nil, err
	}
	if tok == nil {
		return nil, fmt.Errorf("token %d: %s", status, body)
	}
	return tok, nil
}

func FetchUserInfo(userinfoURL, accessToken string) (*UserInfo, error) {
	req, err := http.NewRequest(http.MethodGet, userinfoURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(res.Body)
	if res.StatusCode >= 300 {
		return nil, fmt.Errorf("userinfo %s: %s", res.Status, string(body))
	}
	var ui UserInfo
	if err := json.Unmarshal(body, &ui); err != nil {
		return nil, err
	}
	return &ui, nil
}
