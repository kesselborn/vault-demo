provider "helm" {}

resource "helm_release" "vault_injector" {
  name       = "vault-injector"
  namespace  = "vault-configurator"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.9.1"

  set {
    name  = "injector.externalVaultAddr"
    value = "http://vault.default:8200"
  }

  set {
    name  = "server.service.enabled"
    value = "false"
  }

  set {
    name  = "server.serviceAccount.create"
    value = "true"
  }
}
