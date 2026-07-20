package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFileCredentialsRoundTrip(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_KEYCHAIN", "file")

	c := &Credentials{
		Username:     "op",
		AccessToken:  "at",
		RefreshToken: "rt",
		WarpgateUser: "uat-op-a",
		ExpiresAt:    123,
	}
	if err := SaveCredentials(c); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, "credentials.json")
	if _, err := os.Stat(path); err != nil {
		t.Fatal(err)
	}
	loaded, err := LoadCredentials()
	if err != nil {
		t.Fatal(err)
	}
	if loaded.AccessToken != "at" || loaded.RefreshToken != "rt" {
		t.Fatalf("%+v", loaded)
	}
	if err := ClearCredentials(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("file should be gone")
	}
}

func TestUseKeychainEnv(t *testing.T) {
	t.Setenv("ARCHGATE_KEYCHAIN", "file")
	if UseKeychain() {
		t.Fatal("expected file mode")
	}
	t.Setenv("ARCHGATE_KEYCHAIN", "keychain")
	if !UseKeychain() {
		t.Fatal("expected keychain mode")
	}
}
