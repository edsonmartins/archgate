package cli

import (
	"os"
	"testing"
)

func TestMain(m *testing.M) {
	// Tests must not touch the real OS keychain.
	_ = os.Setenv("ARCHGATE_KEYCHAIN", "file")
	os.Exit(m.Run())
}
