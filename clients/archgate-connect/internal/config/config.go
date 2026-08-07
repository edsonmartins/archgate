package config

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type Bastion struct {
	SSHHost     string `json:"ssh_host"`
	SSHPort     int    `json:"ssh_port"`
	PGHost      string `json:"pg_host"`
	PGPort      int    `json:"pg_port"`
	PGDatabase  string `json:"pg_database"`
	// MySQL via Warpgate protocol proxy (default listen 33306; may be disabled on bastion).
	MySQLHost string `json:"mysql_host"`
	MySQLPort int    `json:"mysql_port"`
	HTTPBase    string `json:"http_base"`
	GuacBase    string `json:"guac_base"`
	ConsoleBase string `json:"console_base"`
	OracleUI    string `json:"oracle_ui"`
}

type Credentials struct {
	AccessToken  string `json:"access_token,omitempty"`
	RefreshToken string `json:"refresh_token,omitempty"`
	// ExpiresAt is Unix seconds when AccessToken should be considered expired.
	// Zero means unknown (refresh only after 401).
	ExpiresAt int64 `json:"expires_at,omitempty"`
	Username  string `json:"username,omitempty"`
	// WarpgateUser is the bastion login (e.g. uat-op-a). Not the target OS user.
	WarpgateUser string `json:"warpgate_user,omitempty"`
	// LabToken is a local-only placeholder until OIDC is wired.
	LabToken string `json:"lab_token,omitempty"`
}

// AccessTokenExpired reports whether the access token should be proactively refreshed.
// skew is how early we refresh (e.g. 60s). If ExpiresAt is 0, returns false (wait for 401).
func (c Credentials) AccessTokenExpired(skew time.Duration) bool {
	if c.AccessToken == "" {
		return true
	}
	if c.ExpiresAt <= 0 {
		return false
	}
	return time.Now().Add(skew).Unix() >= c.ExpiresAt
}

// HasOIDCSession is true when an OIDC access or refresh token is present.
func (c Credentials) HasOIDCSession() bool {
	return c.AccessToken != "" || c.RefreshToken != ""
}

// IsLabSession is true when only lab catalog token is in use (no OIDC access token).
func (c Credentials) IsLabSession() bool {
	return c.LabToken != "" && c.AccessToken == ""
}

type File struct {
	APIBase string      `json:"api_base"`
	Bastion Bastion     `json:"bastion"`
	Creds   Credentials `json:"-"` // stored separately
}

func DefaultBastion() Bastion {
	// SSH/PG must hit the VPS IP: Cloudflare only fronts HTTPS :443 for wg.*
	// (TCP 2222/55432 are published on the Hostinger host.)
	return Bastion{
		SSHHost:     env("ARCHGATE_WG_SSH_HOST", "217.196.60.108"),
		SSHPort:     envInt("ARCHGATE_WG_SSH_PORT", 2222),
		PGHost:      env("ARCHGATE_WG_PG_HOST", "217.196.60.108"),
		PGPort:      envInt("ARCHGATE_WG_PG_PORT", 55432),
		PGDatabase:  env("ARCHGATE_WG_PG_DB", "archgate_lab"),
		MySQLHost:   env("ARCHGATE_WG_MYSQL_HOST", env("ARCHGATE_WG_SSH_HOST", "217.196.60.108")),
		MySQLPort:   envInt("ARCHGATE_WG_MYSQL_PORT", 33306),
		HTTPBase:    env("ARCHGATE_WG_HTTP_BASE", "https://wg.archgate.com.br"),
		GuacBase:    env("ARCHGATE_GUAC_BASE", "https://guac.archgate.com.br"),
		ConsoleBase: env("ARCHGATE_CONSOLE_BASE", "https://console.archgate.com.br"),
		OracleUI:    env("ARCHGATE_ORACLE_UI", "https://console.archgate.com.br/oracle"),
	}
}

func Dir() (string, error) {
	if d := os.Getenv("ARCHGATE_CONFIG_DIR"); d != "" {
		return d, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".config", "archgate"), nil
}

// LoadDotEnv loads KEY=VALUE lines from path into the process env (no overwrite).
func LoadDotEnv(path string) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		line = strings.TrimPrefix(line, "export ")
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.TrimSpace(v)
		v = strings.Trim(v, `"'`)
		if k == "" {
			continue
		}
		if os.Getenv(k) == "" {
			_ = os.Setenv(k, v)
		}
	}
}

// BootstrapEnv loads ~/.config/archgate/oidc.env (and optional local .env) once.
func BootstrapEnv() {
	if d, err := Dir(); err == nil {
		LoadDotEnv(filepath.Join(d, "oidc.env"))
	}
	// Optional project-local override (never commit secrets)
	LoadDotEnv(".env")
	if home, err := os.UserHomeDir(); err == nil {
		LoadDotEnv(filepath.Join(home, ".archgate.env"))
	}
}

func Load() (*File, error) {
	BootstrapEnv()
	dir, err := Dir()
	if err != nil {
		return nil, err
	}
	f := &File{
		APIBase: env("ARCHGATE_API_BASE", "https://console.archgate.com.br/api"),
		Bastion: DefaultBastion(),
	}
	path := filepath.Join(dir, "config.json")
	if b, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(b, f)
	}
	// env always wins for API base when set
	if v := os.Getenv("ARCHGATE_API_BASE"); v != "" {
		f.APIBase = v
	}
	// refresh bastion from env after oidc.env load
	if f.Bastion.SSHHost == "" || os.Getenv("ARCHGATE_WG_SSH_HOST") != "" {
		f.Bastion = DefaultBastion()
	}
	creds, _ := LoadCredentials()
	if creds != nil {
		f.Creds = *creds
	}
	return f, nil
}

func Save(f *File) error {
	dir, err := Dir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	// don't persist creds in config.json
	out := struct {
		APIBase string  `json:"api_base"`
		Bastion Bastion `json:"bastion"`
	}{APIBase: f.APIBase, Bastion: f.Bastion}
	b, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, "config.json"), b, 0o600)
}

func LoadCredentials() (*Credentials, error) {
	// Prefer keychain when enabled; fall back to plaintext file (migration / ARCHGATE_KEYCHAIN=file).
	if UseKeychain() {
		if c, err := loadKeychain(); err == nil && c != nil {
			return c, nil
		}
	}
	return loadFileCredentials()
}

func SaveCredentials(c *Credentials) error {
	if c == nil {
		c = &Credentials{}
	}
	if UseKeychain() {
		if err := saveKeychain(c); err != nil {
			// Fall back to file so login never fails hard on headless/CI.
			if ferr := saveFileCredentials(c); ferr != nil {
				return fmt.Errorf("keychain: %w; file: %v", err, ferr)
			}
			return nil
		}
		// Drop plaintext tokens from disk; leave a pointer file.
		return writeCredsPointer(c, StorageKeychain)
	}
	_ = clearKeychain() // best-effort if switching modes
	return saveFileCredentials(c)
}

func ClearCredentials() error {
	var first error
	// A headless Linux host commonly has the keyring package installed but no
	// Secret Service on D-Bus. File mode must not contact it (tests/CLI servers).
	if UseKeychain() {
		if err := clearKeychain(); err != nil && first == nil {
			first = err
		}
	}
	path, err := credentialsPath()
	if err != nil {
		return err
	}
	if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) && first == nil {
		first = err
	}
	return first
}

func MockMode() bool {
	v := os.Getenv("ARCHGATE_MOCK")
	return v == "1" || v == "true" || v == "yes"
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func envInt(k string, def int) int {
	if v := os.Getenv(k); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}
