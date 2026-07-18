// openbao-oracle-plugin — ADR-001 thin database plugin (dbplugin v5) + lab CLI.
//
// Plugin mode (default — OpenBao/Vault spawns this binary):
//
//	openbao-oracle-plugin
//
// Lab CLI:
//
//	openbao-oracle-plugin -cli -op create -user v_demo -pass 'Secret123!'
//	ORACLE_PLUGIN_CLI=1 go run . -op init-smoke
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/edsonmartins/archgate/services/openbao-oracle-plugin/client"
	"github.com/edsonmartins/archgate/services/openbao-oracle-plugin/oracle"
	dbplugin "github.com/hashicorp/vault/sdk/database/dbplugin/v5"
)

func main() {
	// Detect CLI before Serve (plugin args are opaque).
	if wantsCLI() {
		runCLI()
		return
	}

	dbplugin.ServeMultiplex(func() (interface{}, error) {
		return oracle.New()
	})
}

func wantsCLI() bool {
	if os.Getenv("ORACLE_PLUGIN_CLI") == "1" {
		return true
	}
	for _, a := range os.Args[1:] {
		if a == "-cli" || a == "--cli" {
			return true
		}
		// bare -op without plugin runner
		if a == "-op" || a == "-proxy" || a == "-user" || a == "-pass" {
			return true
		}
	}
	return false
}

func runCLI() {
	cli := flag.Bool("cli", true, "lab CLI mode")
	proxy := flag.String("proxy", env("ORACLE_PROXY_URL", "http://127.0.0.1:9040"), "oracle-proxy base URL")
	op := flag.String("op", "create", "create|update|delete|rotate-root|type|init-smoke")
	user := flag.String("user", "v_lab_user", "username")
	pass := flag.String("pass", "ChangeMe123!", "password")
	_ = cli
	flag.Parse()

	switch *op {
	case "type":
		db, err := oracle.New()
		if err != nil {
			log.Fatal(err)
		}
		t, err := db.Type()
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(t)
		return
	case "init-smoke":
		db, err := oracle.New()
		if err != nil {
			log.Fatal(err)
		}
		_, err = db.Initialize(context.Background(), dbplugin.InitializeRequest{
			Config: map[string]interface{}{"url": *proxy},
		})
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println("initialized")
		_ = db.Close()
		return
	}

	c, err := client.NewWithMTLS(*proxy)
	if err != nil {
		log.Fatal(err)
	}
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
