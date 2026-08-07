package oidc

import "testing"

func TestDefaultIssuerBase(t *testing.T) {
	t.Run("uses the ArchGuard deployment root", func(t *testing.T) {
		t.Setenv("ARCHGATE_IDP_URL", "https://app.archguard.com.br")

		got := defaultIssuerBase()
		want := "https://app.archguard.com.br"
		if got != want {
			t.Fatalf("got %q, want %q", got, want)
		}
	})

	t.Run("defaults to ArchGuard", func(t *testing.T) {
		t.Setenv("ARCHGATE_IDP_URL", "")

		if got := defaultIssuerBase(); got != "https://app.archguard.com.br" {
			t.Fatalf("unexpected default: %q", got)
		}
	})

	t.Run("explicit ARCHGATE_OIDC_ISSUER still wins", func(t *testing.T) {
		t.Setenv("ARCHGATE_OIDC_ISSUER", "https://explicit.example")

		if got := DefaultConfig().IssuerBase; got != "https://explicit.example" {
			t.Fatalf("got %q", got)
		}
	})
}
