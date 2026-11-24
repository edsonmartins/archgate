package config

import "testing"

func TestSSHStrictHostKeyCheckingPolicy(t *testing.T) {
	for _, tc := range []struct {
		name  string
		value string
		want  string
	}{
		{"production", "yes", "yes"},
		{"lab", "accept-new", "accept-new"},
		{"explicit-insecure", "no", "no"},
		{"invalid", "anything-else", "accept-new"},
		{"empty", "", "accept-new"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("ARCHGATE_SSH_STRICT_HOST_KEY_CHECKING", tc.value)
			if got := SSHStrictHostKeyChecking(); got != tc.want {
				t.Fatalf("policy=%q, want %q", got, tc.want)
			}
		})
	}
}
