// Package util holds small shared helpers used across CLI packages.
package util

import (
	"fmt"
	"os/exec"
	"runtime"
	"strings"
)

// Or returns a if non-empty, otherwise b.
func Or(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

// Trunc shortens s to at most n runes-ish bytes with an ellipsis.
func Trunc(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n-1] + "…"
}

// Sanitize produces a safe host-alias fragment: [a-z0-9_-] only.
func Sanitize(s string) string {
	s = strings.ToLower(s)
	var b strings.Builder
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			b.WriteRune(r)
		} else {
			b.WriteByte('-')
		}
	}
	return b.String()
}

// StripAt returns the local part of user@realm (or user unchanged).
func StripAt(user string) string {
	if i := strings.Index(user, "@"); i > 0 {
		return user[:i]
	}
	return user
}

// OpenBrowser launches the system browser for url.
func OpenBrowser(url string) error {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", url)
	case "linux":
		cmd = exec.Command("xdg-open", url)
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	default:
		fmt.Println(url)
		return nil
	}
	return cmd.Start()
}

// TargetSafe reports whether target is safe for shell/AppleScript interpolation.
func TargetSafe(target string) bool {
	if target == "" || len(target) > 128 {
		return false
	}
	for _, r := range target {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') ||
			(r >= '0' && r <= '9') || r == '-' || r == '_' || r == '.' {
			continue
		}
		return false
	}
	return true
}

