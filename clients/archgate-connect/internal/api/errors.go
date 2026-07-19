package api

import (
	"fmt"
	"strings"
)

// StatusError is a non-2xx HTTP response from the BFF.
type StatusError struct {
	Op     string
	Status int
	Body   string
}

func (e *StatusError) Error() string {
	if e == nil {
		return "api status error"
	}
	return fmt.Sprintf("%s %d: %s", e.Op, e.Status, e.Body)
}

// Unauthorized reports HTTP 401.
func (e *StatusError) Unauthorized() bool {
	return e != nil && e.Status == 401
}

// IsUnauthorized reports whether err is an API 401.
func IsUnauthorized(err error) bool {
	if err == nil {
		return false
	}
	if se, ok := err.(*StatusError); ok {
		return se.Unauthorized()
	}
	// Fallback for string-shaped errors from older call sites.
	s := err.Error()
	return strings.Contains(s, " 401") || strings.Contains(s, "401:")
}
