package oracle

// Root rotation is exposed via Database.RotateRootPassword for CLI and ops.
// The Vault/OpenBao secrets engine invokes password change through UpdateUser
// for static roles; dynamic admin rotate uses the CLI helper:
//
//	openbao-oracle-plugin -serve=false -op rotate-root -pass '...'
//
// after Initialize with ORACLE_PROXY_URL.
