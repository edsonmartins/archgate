// Thin OpenBao database plugin frontend (ADR-001 task 2.x scaffold).
//
// Production: implement hashicorp/go-secure-stdlib / vault dbplugin gRPC and
// register with OpenBao plugin catalog. This binary is an HTTP client helper
// used for lab wiring tests against oracle-proxy until the gRPC shim lands.
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	proxy := flag.String("proxy", env("ORACLE_PROXY_URL", "http://127.0.0.1:9040"), "oracle-proxy base URL")
	op := flag.String("op", "create", "create|update|delete|rotate-root")
	user := flag.String("user", "v_lab_user", "username")
	pass := flag.String("pass", "ChangeMe123!", "password")
	flag.Parse()

	client := &http.Client{Timeout: 15 * time.Second}
	var path string
	var body any
	switch *op {
	case "create":
		path = "/v1/oracle/users"
		body = map[string]string{"username": *user, "password": *pass}
	case "update":
		path = "/v1/oracle/users/update"
		body = map[string]string{"username": *user, "password": *pass}
	case "delete":
		path = "/v1/oracle/users/delete"
		body = map[string]string{"username": *user}
	case "rotate-root":
		path = "/v1/oracle/root/rotate"
		body = map[string]string{"password": *pass}
	default:
		log.Fatalf("unknown op %s", *op)
	}

	b, _ := json.Marshal(body)
	req, err := http.NewRequest(http.MethodPost, *proxy+path, bytes.NewReader(b))
	if err != nil {
		log.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()
	out, _ := io.ReadAll(resp.Body)
	fmt.Printf("status=%d body=%s\n", resp.StatusCode, string(out))
	if resp.StatusCode >= 300 {
		os.Exit(1)
	}
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
