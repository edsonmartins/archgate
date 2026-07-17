// Thin OpenBao database plugin frontend (ADR-001).
// CLI uses HTTP client package; gRPC dbplugin registration is next.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/edsonmartins/archgate/services/openbao-oracle-plugin/client"
)

func main() {
	proxy := flag.String("proxy", env("ORACLE_PROXY_URL", "http://127.0.0.1:9040"), "oracle-proxy base URL")
	op := flag.String("op", "create", "create|update|delete|rotate-root")
	user := flag.String("user", "v_lab_user", "username")
	pass := flag.String("pass", "ChangeMe123!", "password")
	flag.Parse()

	c := client.New(*proxy)
	var err error
	switch *op {
	case "create":
		err = c.CreateUser(client.UserRequest{Username: *user, Password: *pass})
	case "update":
		err = c.UpdateUser(client.UserRequest{Username: *user, Password: *pass})
	case "delete":
		err = c.DeleteUser(*user, nil)
	case "rotate-root":
		err = c.RotateRoot(*pass)
	default:
		log.Fatalf("unknown op %s", *op)
	}
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("ok")
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
