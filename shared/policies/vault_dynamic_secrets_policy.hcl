
# Vault Policy for Dynamic Secrets

# Allow access to dynamic database credentials for the app
path "database/creds/app-role" {
  capabilities = ["read"]
}

# Allow access to dynamic AWS credentials for the app
path "aws/creds/app-role" {
  capabilities = ["read"]
}

# General permissions for managing secrets
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
