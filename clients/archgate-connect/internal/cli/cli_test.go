package cli

import (
	"bytes"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/config"
)

func TestLoginStatusLogout(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_MOCK", "1")
	t.Setenv("ARCHGATE_KEYCHAIN", "file")
	t.Setenv("ARCHGATE_WG_USER", "")

	if err := Execute([]string{"login", "--lab", "--user", "tester"}); err != nil {
		t.Fatal(err)
	}
	credPath := filepath.Join(dir, "credentials.json")
	if _, err := os.Stat(credPath); err != nil {
		t.Fatal(err)
	}
	cfg, err := config.Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Creds.Username != "tester" {
		t.Fatalf("user=%q", cfg.Creds.Username)
	}
	if cfg.Creds.WarpgateUser != defaultLabWarpgateUser {
		t.Fatalf("warpgate_user=%q want %q", cfg.Creds.WarpgateUser, defaultLabWarpgateUser)
	}
	if err := Execute([]string{"status"}); err != nil {
		t.Fatal(err)
	}
	if err := Execute([]string{"ls"}); err != nil {
		t.Fatal(err)
	}
	if err := Execute([]string{"ls", "--json"}); err != nil {
		t.Fatal(err)
	}
	if err := Execute([]string{"doctor", "--json"}); err != nil {
		t.Fatal(err)
	}
	if err := Execute([]string{"print-ssh", "rio-lab-ssh"}); err != nil {
		t.Fatal(err)
	}
	if err := Execute([]string{"logout"}); err != nil {
		t.Fatal(err)
	}
}

func TestHelpVersion(t *testing.T) {
	if err := Execute([]string{"help"}); err != nil {
		t.Fatal(err)
	}
	if err := Execute([]string{"version"}); err != nil {
		t.Fatal(err)
	}
	if err := Execute([]string{"version", "--json"}); err != nil {
		t.Fatal(err)
	}
}

func TestPrintSSHUsesWarpgateUserNotCatalogNickname(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_MOCK", "1")
	t.Setenv("ARCHGATE_WG_USER", "")
	t.Setenv("ARCHGATE_WG_SSH_HOST", "217.196.60.108")
	t.Setenv("ARCHGATE_WG_SSH_PORT", "2222")

	// Catalog nickname is not a Warpgate account.
	if err := Execute([]string{"login", "--lab", "--user", "edson"}); err != nil {
		t.Fatal(err)
	}
	cfg, err := config.Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Creds.Username != "edson" {
		t.Fatalf("catalog user=%q", cfg.Creds.Username)
	}
	if cfg.Creds.WarpgateUser != "uat-op-a" {
		t.Fatalf("warpgate_user=%q", cfg.Creds.WarpgateUser)
	}

	out := captureStdout(t, func() {
		if err := Execute([]string{"print-ssh", "rio-lab-ssh"}); err != nil {
			t.Fatal(err)
		}
	})
	if strings.Contains(out, "edson:") || strings.Contains(out, "lab.operator:") {
		t.Fatalf("print-ssh leaked catalog nickname: %s", out)
	}
	if !strings.Contains(out, "uat-op-a:rio-lab-ssh@217.196.60.108") {
		t.Fatalf("expected uat-op-a operator, got: %s", out)
	}

	// JSON form
	jout := captureStdout(t, func() {
		if err := Execute([]string{"print-ssh", "rio-lab-ssh", "--json"}); err != nil {
			t.Fatal(err)
		}
	})
	var payload map[string]any
	if err := json.Unmarshal([]byte(jout), &payload); err != nil {
		t.Fatal(err)
	}
	if payload["operator"] != "uat-op-a" {
		t.Fatalf("operator=%v", payload["operator"])
	}
	user, _ := payload["user"].(string)
	if !strings.HasPrefix(user, "uat-op-a:") {
		t.Fatalf("user=%q", user)
	}
}

func TestPrintSSHHonorsEnvOverride(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_MOCK", "1")
	t.Setenv("ARCHGATE_WG_USER", "custom-op")
	t.Setenv("ARCHGATE_WG_SSH_HOST", "10.0.0.1")

	if err := Execute([]string{"login", "--lab", "--user", "lab.operator"}); err != nil {
		t.Fatal(err)
	}
	// Env wins even after login stored warpgate_user
	out := captureStdout(t, func() {
		if err := Execute([]string{"print-ssh", "rio-lab-ssh"}); err != nil {
			t.Fatal(err)
		}
	})
	if !strings.Contains(out, "custom-op:rio-lab-ssh@") {
		t.Fatalf("expected custom-op, got: %s", out)
	}
}

func TestResolveWarpgateUserErrorsWithoutIdentity(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_MOCK", "1")
	t.Setenv("ARCHGATE_WG_USER", "")

	cfg, err := config.Load()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := resolveWarpgateUser(cfg); err == nil {
		t.Fatal("expected error when no credentials")
	}
}

func TestLabOperatorNeverInSSHLine(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_MOCK", "1")
	t.Setenv("ARCHGATE_WG_USER", "")
	t.Setenv("ARCHGATE_WG_SSH_HOST", "217.196.60.108")

	if err := Execute([]string{"login", "--lab", "--user", "lab.operator"}); err != nil {
		t.Fatal(err)
	}
	out := captureStdout(t, func() {
		if err := Execute([]string{"print-ssh", "rio-lab-ssh"}); err != nil {
			t.Fatal(err)
		}
	})
	if strings.Contains(out, "lab.operator") {
		t.Fatalf("lab.operator must not appear in ssh line: %s", out)
	}
	if !strings.Contains(out, "uat-op-a:rio-lab-ssh@217.196.60.108") {
		t.Fatalf("got: %s", out)
	}
}

func TestFindConnPartialAndAmbiguous(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_MOCK", "1")
	t.Setenv("ARCHGATE_WG_USER", "")

	if err := Execute([]string{"login", "--lab", "--user", "t"}); err != nil {
		t.Fatal(err)
	}
	// unique partial
	if err := Execute([]string{"print-ssh", "rio-lab-ssh"}); err != nil {
		t.Fatal(err)
	}
	// ambiguous "lab" matches multiple
	err := Execute([]string{"print-ssh", "lab"})
	if err == nil {
		t.Fatal("expected ambiguous error")
	}
	if !strings.Contains(err.Error(), "ambiguous") {
		t.Fatalf("want ambiguous, got %v", err)
	}
}

func TestIsCloudflareOnlyHost(t *testing.T) {
	if !isCloudflareOnlyHost("wg.archgate.com.br") {
		t.Fatal("expected true")
	}
	if !isCloudflareOnlyHost("wg.lab.archgate.com.br") {
		t.Fatal("expected true for wg.*.archgate.com.br")
	}
	if isCloudflareOnlyHost("console.archgate.com.br") {
		t.Fatal("console is not CF-only SSH host")
	}
	if isCloudflareOnlyHost("217.196.60.108") {
		t.Fatal("IP is not CF host")
	}
}

func TestWgUserSetAndGet(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("ARCHGATE_CONFIG_DIR", dir)
	t.Setenv("ARCHGATE_MOCK", "1")
	t.Setenv("ARCHGATE_KEYCHAIN", "file")
	t.Setenv("ARCHGATE_WG_USER", "")

	if err := Execute([]string{"login", "--lab", "--user", "tester"}); err != nil {
		t.Fatal(err)
	}
	if err := Execute([]string{"wg-user", "custom-op"}); err != nil {
		t.Fatal(err)
	}
	cfg, err := config.Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Creds.WarpgateUser != "custom-op" {
		t.Fatalf("stored=%q", cfg.Creds.WarpgateUser)
	}
	out := captureStdout(t, func() {
		if err := Execute([]string{"wg-user", "--json"}); err != nil {
			t.Fatal(err)
		}
	})
	if !strings.Contains(out, "custom-op") {
		t.Fatalf("json: %s", out)
	}
}

func TestManagerPathOK(t *testing.T) {
	ok := []string{"/dashboard", "/sites", "/sites/wizard", "/gateways", "/identities"}
	for _, p := range ok {
		if !managerPathOK(p) {
			t.Fatalf("expected ok path %q", p)
		}
	}
	bad := []string{"", "dashboard", "//evil", "https://evil", "/sites?x=1", "/a b", "/../x"}
	for _, p := range bad {
		if managerPathOK(p) {
			t.Fatalf("expected reject path %q", p)
		}
	}
}

func TestManagerHelp(t *testing.T) {
	out := captureStdout(t, func() {
		if err := Execute([]string{"manager", "--help"}); err != nil {
			t.Fatal(err)
		}
	})
	if !strings.Contains(out, "usage: archgate manager") {
		t.Fatalf("help: %s", out)
	}
}

func TestHelpListsManager(t *testing.T) {
	out := captureStdout(t, func() {
		if err := Execute([]string{"help"}); err != nil {
			t.Fatal(err)
		}
	})
	if !strings.Contains(out, "archgate manager") {
		t.Fatalf("help missing manager: %s", out)
	}
}

func captureStdout(t *testing.T, fn func()) string {
	t.Helper()
	old := os.Stdout
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stdout = w
	fn()
	_ = w.Close()
	os.Stdout = old
	var buf bytes.Buffer
	_, _ = io.Copy(&buf, r)
	_ = r.Close()
	return buf.String()
}
