provider vault {}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "k8sCluster" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = local.kubernetes_host
  token_reviewer_jwt     = data.kubernetes_secret.vault_auth_token.data.token
  issuer                 = "api"
  disable_iss_validation = "true"
}

# Create admin policy in the root namespace
resource "vault_policy" "vault_configurator" {
  name   = "vault_configurator"
  policy = file("vault-configurator-policy.hcl")
}

# path where admins can save passwords
resource "vault_mount" "admin" {
  path        = "admin/secrets"
  type        = "generic"
  description = "store single passwords here for later reference"
}
