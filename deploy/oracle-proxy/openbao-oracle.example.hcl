# OpenBao database config — ArchGate Oracle (ADR-001)
# Prerequisites:
#   1. openbao-oracle-plugin in plugin_directory + catalog (register-plugin.sh)
#   2. oracle-proxy reachable (mTLS recommended: ORACLE_PROXY_* certs on OpenBao host)
#   3. database secrets engine mounted at database/

# path "sys/plugins/catalog/database/oracle-archgate" {
#   # applied via CLI; sha256 from binary
# }

# Connection — plugin reads `url` as oracle-proxy base
#
# bao write database/config/oracle-rio-quality \
#   plugin_name="oracle-archgate" \
#   allowed_roles="oracle-readonly,oracle-app" \
#   url="https://oracle-proxy:9040" \
#   require_mtls="true" \
#   username="unused" \
#   password="unused" \
#   verify_connection=false

# Role — statements executed by Java proxy (JDBC)
#
# bao write database/roles/oracle-readonly \
#   db_name=oracle-rio-quality \
#   creation_statements=$'CREATE USER {{name}} IDENTIFIED BY "{{password}}";\nGRANT CREATE SESSION TO {{name}};' \
#   revocation_statements='DROP USER {{name}} CASCADE;' \
#   default_ttl=30m \
#   max_ttl=2h \
#   username_template='v_{{random 8}}'

# --- Identity binding (Kanidm JWT → policy) ---
# Operators authenticate to OpenBao via JWT (Kanidm). Bound claims restrict
# which groups can read database/creds/oracle-readonly.
#
# path "auth/jwt/role/archgate-operator" {
#   bound_audiences = ["openbao"]
#   user_claim      = "preferred_username"
#   groups_claim    = "groups"
#   policies        = ["archgate-oracle-ro"]
#   ttl             = "1h"
# }
#
# policy archgate-oracle-ro:
#   path "database/creds/oracle-readonly" {
#     capabilities = ["read"]
#   }
#   # Optional: require group tenant_rio_quality via identity group policies
