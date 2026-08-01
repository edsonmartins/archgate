package oidc

import "testing"

// Kanidm publishes one issuer per client; ArchGuard publishes a single issuer
// for the deployment. Only the discovery root differs — the rest of the
// endpoints come from the discovery document.
func TestDefaultIssuerBasePerIdP(t *testing.T) {
	t.Run("kanidm keeps the per-client path", func(t *testing.T) {
		t.Setenv("ARCHGATE_IDP", "kanidm")
		t.Setenv("ARCHGATE_IDP_URL", "https://id.archgate.com.br")
		t.Setenv("ARCHGATE_OIDC_CLIENT_ID", "archgate-connect")

		got := defaultIssuerBase()
		want := "https://id.archgate.com.br/oauth2/openid/archgate-connect"
		if got != want {
			t.Fatalf("got %q, want %q", got, want)
		}
	})

	t.Run("archguard uses the deployment root", func(t *testing.T) {
		t.Setenv("ARCHGATE_IDP", "archguard")
		t.Setenv("ARCHGATE_IDP_URL", "https://app.archguard.com.br")

		got := defaultIssuerBase()
		want := "https://app.archguard.com.br"
		if got != want {
			t.Fatalf("got %q, want %q", got, want)
		}
	})

	t.Run("defaults to kanidm so an existing install is untouched", func(t *testing.T) {
		t.Setenv("ARCHGATE_IDP", "")
		t.Setenv("ARCHGATE_IDP_URL", "")
		t.Setenv("ARCHGATE_OIDC_CLIENT_ID", "")

		if got := defaultIssuerBase(); got != "https://id.archgate.com.br/oauth2/openid/archgate-connect" {
			t.Fatalf("unexpected default: %q", got)
		}
	})

	t.Run("explicit ARCHGATE_OIDC_ISSUER still wins", func(t *testing.T) {
		t.Setenv("ARCHGATE_IDP", "archguard")
		t.Setenv("ARCHGATE_OIDC_ISSUER", "https://explicit.example")

		if got := DefaultConfig().IssuerBase; got != "https://explicit.example" {
			t.Fatalf("got %q", got)
		}
	})
}
