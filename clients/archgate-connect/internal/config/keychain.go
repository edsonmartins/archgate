package config

import (
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/zalando/go-keyring"
)

const (
	keyringService        = "archgate-connect"
	keyringAccountDefault = "credentials"
)

// keyringAccountName isolates secrets when ARCHGATE_CONFIG_DIR is set (tests/tmp).
func keyringAccountName() string {
	if d := strings.TrimSpace(os.Getenv("ARCHGATE_CONFIG_DIR")); d != "" {
		sum := sha256.Sum256([]byte(d))
		return fmt.Sprintf("credentials-%x", sum[:8])
	}
	return keyringAccountDefault
}

// CredentialsStorage reports where secrets are kept.
type CredentialsStorage string

const (
	StorageFile     CredentialsStorage = "file"
	StorageKeychain CredentialsStorage = "keychain"
)

// UseKeychain is true when secrets should prefer OS keychain/credential store.
// Override: ARCHGATE_KEYCHAIN=0|file  → force file
//           ARCHGATE_KEYCHAIN=1|keychain → force keychain
func UseKeychain() bool {
	v := strings.ToLower(strings.TrimSpace(os.Getenv("ARCHGATE_KEYCHAIN")))
	switch v {
	case "0", "false", "no", "file":
		return false
	case "1", "true", "yes", "keychain":
		return true
	default:
		// Prefer keychain on desktop OSes; tests use ARCHGATE_KEYCHAIN=file.
		return runtime.GOOS == "darwin" || runtime.GOOS == "windows" || runtime.GOOS == "linux"
	}
}

func saveKeychain(c *Credentials) error {
	b, err := json.Marshal(c)
	if err != nil {
		return err
	}
	return keyring.Set(keyringService, keyringAccountName(), string(b))
}

func loadKeychain() (*Credentials, error) {
	s, err := keyring.Get(keyringService, keyringAccountName())
	if err != nil {
		return nil, err
	}
	var c Credentials
	if err := json.Unmarshal([]byte(s), &c); err != nil {
		return nil, err
	}
	return &c, nil
}

func clearKeychain() error {
	err := keyring.Delete(keyringService, keyringAccountName())
	if err == nil || errors.Is(err, keyring.ErrNotFound) {
		return nil
	}
	// Some platforms return a plain string error for missing item.
	if strings.Contains(strings.ToLower(err.Error()), "not found") {
		return nil
	}
	return err
}

// writeCredsPointer writes a non-secret marker file so operators know keychain is in use.
func writeCredsPointer(c *Credentials, storage CredentialsStorage) error {
	dir, err := Dir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	meta := map[string]any{
		"storage": string(storage),
		"hint":    "OIDC tokens live in the OS keychain (service=archgate-connect). Set ARCHGATE_KEYCHAIN=file to force credentials.json.",
	}
	if c != nil {
		if c.Username != "" {
			meta["username"] = c.Username
		}
		if c.WarpgateUser != "" {
			meta["warpgate_user"] = c.WarpgateUser
		}
		if c.IsLabSession() {
			meta["auth"] = "lab"
		} else if c.HasOIDCSession() {
			meta["auth"] = "oidc"
		}
	}
	b, err := json.MarshalIndent(meta, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, "credentials.json"), b, 0o600)
}

func credentialsPath() (string, error) {
	dir, err := Dir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "credentials.json"), nil
}

func loadFileCredentials() (*Credentials, error) {
	path, err := credentialsPath()
	if err != nil {
		return nil, err
	}
	b, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return &Credentials{}, nil
		}
		return nil, err
	}
	// Pointer-only file (no tokens) → empty session from file perspective.
	var probe map[string]any
	if err := json.Unmarshal(b, &probe); err == nil {
		if st, _ := probe["storage"].(string); st == string(StorageKeychain) {
			if _, hasTok := probe["access_token"]; !hasTok {
				if _, hasLab := probe["lab_token"]; !hasLab {
					return &Credentials{}, nil
				}
			}
		}
	}
	var c Credentials
	if err := json.Unmarshal(b, &c); err != nil {
		return nil, err
	}
	return &c, nil
}

func saveFileCredentials(c *Credentials) error {
	path, err := credentialsPath()
	if err != nil {
		return err
	}
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	b, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, b, 0o600)
}

// StorageBackend returns the active credentials backend for status/docs.
func StorageBackend() CredentialsStorage {
	if UseKeychain() {
		return StorageKeychain
	}
	return StorageFile
}

// DescribeStorage is a short human label for status output.
func DescribeStorage() string {
	if UseKeychain() {
		return fmt.Sprintf("keychain (%s/%s)", keyringService, keyringAccountName())
	}
	return "file (~/.config/archgate/credentials.json)"
}
