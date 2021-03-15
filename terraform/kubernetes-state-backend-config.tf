terraform {
  backend "kubernetes" {
    namespace     = "vault-configurator"
    secret_suffix = "state"
  }
}
