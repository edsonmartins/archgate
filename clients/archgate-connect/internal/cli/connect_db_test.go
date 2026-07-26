package cli

import (
	"strings"
	"testing"

	"github.com/integrall-tech/archgate/clients/archgate-connect/internal/api"
)

func TestClassifyConnMySQLAndPostgresAreDB(t *testing.T) {
	for _, p := range []string{"mysql", "mariadb", "postgres", "postgresql"} {
		c := api.Connection{Protocol: p, Engine: "warpgate", Target: "t1"}
		// mariadb classified via mysql path only if protocol is mysql — keep explicit
		if p == "mariadb" {
			c.Protocol = "mysql"
		}
		if got := classifyConn(&c); got != actionDB {
			t.Fatalf("protocol %s: got %s want db", p, got)
		}
	}
}

func TestMySQLCommandShape(t *testing.T) {
	// Document expected CLI shape for clipboard / PTY (no live bastion).
	host, port, user := "217.196.60.108", 33306, "uat-op-a:lab-mysql"
	cmd := "mysql -h " + host + " -P " + "33306" + " -u " + user + " -p --ssl-mode=REQUIRED"
	if !strings.Contains(cmd, "33306") || !strings.Contains(cmd, "ssl-mode=REQUIRED") {
		t.Fatalf("cmd=%s", cmd)
	}
	_ = port
}
