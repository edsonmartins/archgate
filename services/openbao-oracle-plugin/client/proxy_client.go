package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// ProxyClient talks to archgate oracle-proxy HTTP API (pre-mTLS lab / scaffold).
type ProxyClient struct {
	BaseURL    string
	HTTPClient *http.Client
}

func New(baseURL string) *ProxyClient {
	return &ProxyClient{
		BaseURL: baseURL,
		HTTPClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

type UserRequest struct {
	Username   string            `json:"username"`
	Password   string            `json:"password,omitempty"`
	Expiration string            `json:"expiration,omitempty"`
	Statements map[string]string `json:"statements,omitempty"`
}

func (c *ProxyClient) CreateUser(req UserRequest) error {
	return c.post("/v1/oracle/users", req)
}

func (c *ProxyClient) UpdateUser(req UserRequest) error {
	return c.post("/v1/oracle/users/update", req)
}

func (c *ProxyClient) DeleteUser(username string, statements map[string]string) error {
	return c.post("/v1/oracle/users/delete", UserRequest{Username: username, Statements: statements})
}

func (c *ProxyClient) RotateRoot(password string) error {
	return c.post("/v1/oracle/root/rotate", map[string]string{"password": password})
}

func (c *ProxyClient) post(path string, body any) error {
	b, err := json.Marshal(body)
	if err != nil {
		return err
	}
	resp, err := c.HTTPClient.Post(c.BaseURL+path, "application/json", bytes.NewReader(b))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	out, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return fmt.Errorf("proxy %s: %s", resp.Status, string(out))
	}
	return nil
}
