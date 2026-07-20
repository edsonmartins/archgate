package cli

import (
	"testing"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/api"
)

func TestClassifyConn(t *testing.T) {
	cases := []struct {
		name string
		c    api.Connection
		want dispatchAction
	}{
		{"ssh warpgate", api.Connection{Protocol: "ssh", Engine: "warpgate", Target: "rio-lab-ssh"}, actionSSH},
		{"guac open", api.Connection{Protocol: "ssh", Engine: "guacamole", Target: "lab-ssh-browser"}, actionOpen},
		{"pg", api.Connection{Protocol: "postgres", Engine: "warpgate", Target: "rio-lab-postgres"}, actionDB},
		{"mysql", api.Connection{Protocol: "mysql", Engine: "warpgate", Target: "db1"}, actionDB},
		{"http", api.Connection{Protocol: "http", Engine: "warpgate", Target: "app"}, actionOpen},
		{"oracle name", api.Connection{Protocol: "ssh", Engine: "warpgate", Target: "rio-oracle-prod"}, actionOpen},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			c := tc.c
			if got := classifyConn(&c); got != tc.want {
				t.Fatalf("got %s want %s", got, tc.want)
			}
		})
	}
}
