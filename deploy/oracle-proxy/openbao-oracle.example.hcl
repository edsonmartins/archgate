# Example OpenBao database config for ADR-001 (after Go dbplugin gRPC is registered).
# Do NOT apply until plugin binary is in catalog and mTLS to proxy works.
#
#   bao write sys/plugins/catalog/database/oracle-archgate \
#     sha256=... command=openbao-oracle-plugin
#
# Connection (conceptual — field names follow Vault/OpenBao database plugin API):

# path "database/config/oracle-consico" {
#   plugin_name    = "oracle-archgate"
#   allowed_roles  = ["oracle-readonly"]
#   # plugin_config / connection_url → proxy URL + mTLS paths
#   url            = "https://oracle-proxy:9040"
#   username       = ""   # unused if proxy holds admin
#   password       = ""
# }

# path role example (statements executed by proxy):
#
# bao write database/roles/oracle-readonly \
#   db_name=oracle-consico \
#   creation_statements='CREATE USER {{username}} IDENTIFIED BY "{{password}}"; GRANT CREATE SESSION TO {{username}};' \
#   revocation_statements='DROP USER {{username}} CASCADE;' \
#   default_ttl=30m \
#   max_ttl=2h \
#   username_template='v_{{random 8}}'
