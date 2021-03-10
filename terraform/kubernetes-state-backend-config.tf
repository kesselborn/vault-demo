terraform {
  backend "kubernetes" {
    namespace        = "vault-configurator"
    secret_suffix    = "state"
    load_config_file = true
  }
}
