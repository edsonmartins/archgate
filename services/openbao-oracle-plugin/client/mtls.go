package client

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net/http"
	"os"
	"time"
)

// TLSConfigFromEnv builds optional client TLS for mTLS to oracle-proxy.
// Env:
//
//	ORACLE_PROXY_CLIENT_CERT  path to client cert PEM
//	ORACLE_PROXY_CLIENT_KEY   path to client key PEM
//	ORACLE_PROXY_CA_CERT      path to CA PEM (required if mTLS)
func TLSConfigFromEnv() (*tls.Config, error) {
	certFile := os.Getenv("ORACLE_PROXY_CLIENT_CERT")
	keyFile := os.Getenv("ORACLE_PROXY_CLIENT_KEY")
	caFile := os.Getenv("ORACLE_PROXY_CA_CERT")
	if certFile == "" || keyFile == "" {
		return nil, nil // plain HTTP
	}
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		return nil, fmt.Errorf("client cert: %w", err)
	}
	cfg := &tls.Config{
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS12,
	}
	if caFile != "" {
		pem, err := os.ReadFile(caFile)
		if err != nil {
			return nil, err
		}
		pool := x509.NewCertPool()
		if !pool.AppendCertsFromPEM(pem) {
			return nil, fmt.Errorf("no certs in CA file")
		}
		cfg.RootCAs = pool
	}
	return cfg, nil
}

// NewWithMTLS returns a client; if mTLS env not set, behaves like New().
func NewWithMTLS(baseURL string) (*ProxyClient, error) {
	c := New(baseURL)
	tlsCfg, err := TLSConfigFromEnv()
	if err != nil {
		return nil, err
	}
	if tlsCfg != nil {
		c.HTTPClient = &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: tlsCfg,
			},
		}
	}
	return c, nil
}
