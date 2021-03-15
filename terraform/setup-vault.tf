variable "vault_addr" {
  type    = string
  default = null
  validation {
    condition     = var.vault_addr != null
    error_message = "Either call with '--set vault_addr=https://<vault endpoint>' or set $TF_VAR_vault_addr respectively."
  }
}

variable "vault_token" {
  type    = string
  default = null
  validation {
    condition     = var.vault_token != null
    error_message = "Either call with '--set vault_token=<vault token>' or set $TF_VAR_vault_token respectively."
  }
}

provider vault {
  address = var.vault_addr
  token = var.vault_token
}

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

# path where admins can save passwords
resource "vault_mount" "admin" {
  path        = "admin/secrets"
  type        = "generic"
  description = "store single passwords here for later reference"
}
