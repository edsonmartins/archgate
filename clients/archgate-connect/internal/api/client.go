package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/config"
)

type Connection struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Site        string `json:"site"`
	Tenant      string `json:"tenant"`
	Protocol    string `json:"protocol"`
	Engine      string `json:"engine"`
	Target      string `json:"target"`
	Description string `json:"description,omitempty"`
}

type Profile struct {
	DisplayName string   `json:"display_name"`
	Email       string   `json:"email"`
	Username    string   `json:"username"`
	Tenants     []string `json:"tenants"`
}

type Bootstrap struct {
	Bastion     config.Bastion `json:"bastion"`
	Profile     Profile        `json:"profile"`
	Connections []Connection   `json:"connections"`
}

type Client struct {
	BaseURL string
	Token   string
	HTTP    *http.Client
}

func New(cfg *config.File) *Client {
	token := cfg.Creds.AccessToken
	if token == "" {
		token = cfg.Creds.LabToken
	}
	return &Client{
		BaseURL: strings.TrimRight(cfg.APIBase, "/"),
		Token:   token,
		HTTP:    &http.Client{Timeout: 15 * time.Second},
	}
}

func MockBootstrap(cfg *config.File) *Bootstrap {
	user := cfg.Creds.Username
	if user == "" {
		user = "lab.operator"
	}
	return &Bootstrap{
		Bastion: cfg.Bastion,
		Profile: Profile{
			DisplayName: user,
			Username:    user,
			Tenants:     []string{"tenant_rio_quality"},
		},
		Connections: []Connection{
			{
				ID: "lab:rio-lab-ssh", Name: "rio-lab-ssh", Site: "Rio Quality (lab)",
				Tenant: "tenant_rio_quality", Protocol: "ssh", Engine: "warpgate", Target: "rio-lab-ssh",
				Description: "mock lab SSH",
			},
			{
				ID: "lab:rio-lab-postgres", Name: "rio-lab-postgres", Site: "Rio Quality (lab)",
				Tenant: "tenant_rio_quality", Protocol: "postgres", Engine: "warpgate", Target: "rio-lab-postgres",
				Description: "mock lab Postgres",
			},
			{
				ID: "lab:lab-ssh-browser", Name: "lab-ssh-browser", Site: "Lab",
				Tenant: "tenant_rio_quality", Protocol: "ssh", Engine: "guacamole", Target: "lab-ssh-browser",
				Description: "mock Guac SSH web",
			},
		},
	}
}

func (c *Client) Bootstrap() (*Bootstrap, error) {
	req, err := http.NewRequest(http.MethodGet, c.BaseURL+"/unified/v1/operator/bootstrap", nil)
	if err != nil {
		return nil, err
	}
	if c.Token != "" {
		req.Header.Set("Authorization", "Bearer "+c.Token)
	}
	req.Header.Set("Accept", "application/json")
	res, err := c.HTTP.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(res.Body)
	if res.StatusCode >= 300 {
		return nil, fmt.Errorf("bootstrap %s: %s", res.Status, truncate(string(body), 200))
	}
	var b Bootstrap
	if err := json.Unmarshal(body, &b); err != nil {
		return nil, err
	}
	return &b, nil
}

func (c *Client) Connections() ([]Connection, error) {
	req, err := http.NewRequest(http.MethodGet, c.BaseURL+"/unified/v1/connections", nil)
	if err != nil {
		return nil, err
	}
	if c.Token != "" {
		req.Header.Set("Authorization", "Bearer "+c.Token)
	}
	req.Header.Set("Accept", "application/json")
	res, err := c.HTTP.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(res.Body)
	if res.StatusCode >= 300 {
		return nil, fmt.Errorf("connections %s: %s", res.Status, truncate(string(body), 200))
	}
	var wrap struct {
		Connections []Connection `json:"connections"`
	}
	if err := json.Unmarshal(body, &wrap); err != nil {
		return nil, err
	}
	return wrap.Connections, nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}
