# Auto-unseal via Transit (OpenBao root-of-trust separado)
# W5-HA01 — seal stanza a mesclar no config do cluster de aplicação

seal "transit" {
  address         = "https://openbao-root.internal:8200"
  token           = "s.REPLACE_WITH_WRAPPED_OR_APPROLE" # prefer AppRole / K8s auth
  disable_renewal = "false"
  key_name        = "autounseal"
  mount_path      = "transit/"
  tls_skip_verify = "false"
}

# Alternativa conceitual (não commitar secrets):
# seal "awskms" {
#   region     = "sa-east-1"
#   kms_key_id = "alias/archgate-openbao"
# }
