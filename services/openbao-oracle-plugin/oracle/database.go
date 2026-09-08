// Package oracle implements OpenBao/Vault database plugin v5 (ADR-001).
// SQL runs only inside the Java oracle-proxy (JDBC thin); this binary stays free of Oracle libs.
package oracle

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/edsonmartins/archgate/services/openbao-oracle-plugin/client"
	dbplugin "github.com/hashicorp/vault/sdk/database/dbplugin/v5"
)

const pluginType = "oracle-archgate"

// Database is the thin dbplugin that only talks to oracle-proxy.
type Database struct {
	mu     sync.RWMutex
	proxy  *client.ProxyClient
	url    string
	closed bool
}

// Factory for ServeMultiplex.
func Factory() (interface{}, error) {
	return New()
}

// New returns an uninitialized plugin instance.
func New() (dbplugin.Database, error) {
	return &Database{}, nil
}

func (d *Database) Type() (string, error) {
	return pluginType, nil
}

func (d *Database) Initialize(ctx context.Context, req dbplugin.InitializeRequest) (dbplugin.InitializeResponse, error) {
	_ = ctx
	cfg := req.Config
	if cfg == nil {
		cfg = map[string]interface{}{}
	}
	url := firstString(cfg, "url", "proxy_url", "connection_url", "oracle_proxy_url")
	if url == "" {
		url = os.Getenv("ORACLE_PROXY_URL")
	}
	if url == "" {
		return dbplugin.InitializeResponse{}, fmt.Errorf("oracle-archgate: missing proxy url (url/proxy_url)")
	}
	url = strings.TrimRight(url, "/")

	requireMTLS := envTruthy("ORACLE_PROXY_REQUIRE_MTLS") || firstString(cfg, "require_mtls") == "true"
	c, err := client.NewWithMTLS(url)
	if err != nil {
		return dbplugin.InitializeResponse{}, err
	}
	if requireMTLS && !client.HasMTLSEnv() {
		return dbplugin.InitializeResponse{}, fmt.Errorf("oracle-archgate: mTLS required but ORACLE_PROXY_CLIENT_CERT/KEY not set")
	}

	// Persist connection config for Vault/OpenBao (no secrets).
	out := map[string]interface{}{}
	for k, v := range cfg {
		out[k] = v
	}
	out["url"] = url
	if requireMTLS {
		out["require_mtls"] = "true"
	}
	resp := dbplugin.InitializeResponse{Config: out}
	resp.SetSupportedCredentialTypes([]dbplugin.CredentialType{dbplugin.CredentialTypePassword})

	d.mu.Lock()
	d.proxy = c
	d.url = url
	d.closed = false
	d.mu.Unlock()

	return resp, nil
}

func (d *Database) NewUser(ctx context.Context, req dbplugin.NewUserRequest) (dbplugin.NewUserResponse, error) {
	_ = ctx
	p, err := d.client()
	if err != nil {
		return dbplugin.NewUserResponse{}, err
	}
	if req.Password == "" {
		return dbplugin.NewUserResponse{}, fmt.Errorf("oracle-archgate: empty password from secrets engine")
	}
	username, err := generateUsername(req.UsernameConfig)
	if err != nil {
		return dbplugin.NewUserResponse{}, err
	}
	exp := ""
	if !req.Expiration.IsZero() {
		exp = req.Expiration.UTC().Format(time.RFC3339)
	}
	if err := p.CreateUser(client.UserRequest{
		Username:   username,
		Password:   req.Password,
		Expiration: exp,
		Statements: statementsMap(req.Statements.Commands),
	}); err != nil {
		return dbplugin.NewUserResponse{}, err
	}
	return dbplugin.NewUserResponse{Username: username}, nil
}

func (d *Database) UpdateUser(ctx context.Context, req dbplugin.UpdateUserRequest) (dbplugin.UpdateUserResponse, error) {
	_ = ctx
	p, err := d.client()
	if err != nil {
		return dbplugin.UpdateUserResponse{}, err
	}
	if req.Username == "" {
		return dbplugin.UpdateUserResponse{}, fmt.Errorf("oracle-archgate: username required")
	}
	password := ""
	var cmds []string
	if req.Password != nil {
		password = req.Password.NewPassword
		cmds = req.Password.Statements.Commands
	}
	if password == "" && req.Expiration == nil {
		return dbplugin.UpdateUserResponse{}, nil
	}
	if err := p.UpdateUser(client.UserRequest{
		Username:   req.Username,
		Password:   password,
		Statements: statementsMap(cmds),
	}); err != nil {
		return dbplugin.UpdateUserResponse{}, err
	}
	return dbplugin.UpdateUserResponse{}, nil
}

func (d *Database) DeleteUser(ctx context.Context, req dbplugin.DeleteUserRequest) (dbplugin.DeleteUserResponse, error) {
	_ = ctx
	p, err := d.client()
	if err != nil {
		return dbplugin.DeleteUserResponse{}, err
	}
	if req.Username == "" {
		return dbplugin.DeleteUserResponse{}, nil
	}
	if err := p.DeleteUser(req.Username, statementsMap(req.Statements.Commands)); err != nil {
		// Idempotent: proxy may 404-equivalent — still surface error for ops visibility.
		return dbplugin.DeleteUserResponse{}, err
	}
	return dbplugin.DeleteUserResponse{}, nil
}

func (d *Database) Close() error {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.closed = true
	d.proxy = nil
	return nil
}

// RotateRootPassword updates admin credentials held by the proxy (CLI / catalog ops).
func (d *Database) RotateRootPassword(ctx context.Context, newPassword string) error {
	_ = ctx
	if newPassword == "" {
		return fmt.Errorf("oracle-archgate: new root password required")
	}
	p, err := d.client()
	if err != nil {
		return err
	}
	return p.RotateRoot(newPassword)
}

func (d *Database) client() (*client.ProxyClient, error) {
	d.mu.RLock()
	defer d.mu.RUnlock()
	if d.closed || d.proxy == nil {
		return nil, fmt.Errorf("oracle-archgate: not initialized")
	}
	return d.proxy, nil
}

func generateUsername(meta dbplugin.UsernameMetadata) (string, error) {
	role := sanitizeIdent(meta.RoleName, 8)
	if role == "" {
		role = "u"
	}
	b := make([]byte, 4)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	// Oracle identifier ≤ 30; prefix v_ for dynamic users.
	u := fmt.Sprintf("v_%s_%s", role, hex.EncodeToString(b))
	if len(u) > 30 {
		u = u[:30]
	}
	return strings.ToLower(u), nil
}

func sanitizeIdent(s string, max int) string {
	var b strings.Builder
	for _, r := range strings.ToLower(s) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
		if b.Len() >= max {
			break
		}
	}
	return b.String()
}

func statementsMap(cmds []string) map[string]string {
	if len(cmds) == 0 {
		return nil
	}
	// Keep one logical value per lifecycle phase. Exposing cmd_N values makes
	// compatibility consumers execute every command for every phase.
	m := map[string]string{
		"creation_statements": cmds[0],
		"renewal_statements": cmds[0],
		"revocation_statements": cmds[len(cmds)-1],
	}
	return m
}

func firstString(cfg map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := cfg[k]; ok && v != nil {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

func envTruthy(k string) bool {
	v := strings.ToLower(os.Getenv(k))
	return v == "1" || v == "true" || v == "yes"
}

var _ dbplugin.Database = (*Database)(nil)
