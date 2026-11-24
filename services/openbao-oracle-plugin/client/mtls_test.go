package client

import "testing"

func TestNewWithMTLSFailsWhenRequiredWithoutCertificate(t *testing.T) {
	t.Setenv("ORACLE_PROXY_REQUIRE_MTLS", "true")
	t.Setenv("ORACLE_PROXY_CLIENT_CERT", "")
	t.Setenv("ORACLE_PROXY_CLIENT_KEY", "")

	if _, err := NewWithMTLS("https://oracle-proxy.example"); err == nil {
		t.Fatal("expected mTLS configuration error")
	}
}

func TestNewWithMTLSAllowsExplicitLabPlainHTTP(t *testing.T) {
	t.Setenv("ORACLE_PROXY_REQUIRE_MTLS", "false")
	t.Setenv("ORACLE_PROXY_CLIENT_CERT", "")
	t.Setenv("ORACLE_PROXY_CLIENT_KEY", "")

	if _, err := NewWithMTLS("http://127.0.0.1:9040"); err != nil {
		t.Fatalf("unexpected lab client error: %v", err)
	}
}
