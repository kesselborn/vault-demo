resource "kubernetes_job" "terraform-runner" {
  count = 0
  metadata {
    name      = "terraform-runner"
    namespace = "vault-configurator"
  }

  spec {
    template {
      metadata {
        annotations = {
          "vault.hashicorp.com/agent-inject"       = "true"
          "vault.hashicorp.com/agent-inject-token" = "true"
          "vault.hashicorp.com/log-level"          = "debug"
          "vault.hashicorp.com/role"               = "terraform-runner"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.terraform.metadata[0].name

        container {
          image_pull_policy = "IfNotPresent"
          name    = "terraform-runner"
          image   = "terraform-runner"
          command = ["sh", "-c", "source setup-env.source && terraform plan && terraform apply -auto-approve"]
        }

        restart_policy = "Never"
      }
    }

    backoff_limit = 4
  }

  wait_for_completion = false
}

# Create admin policy in the root namespace
resource "vault_policy" "vault_configurator" {
  name   = "vault_configurator"
  policy = file("vault-configurator-policy.hcl")
}


resource "vault_kubernetes_auth_backend_role" "terraform-runner" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "terraform-runner"
  bound_service_account_names      = [kubernetes_service_account.terraform.metadata[0].name]
  bound_service_account_namespaces = [kubernetes_service_account.terraform.metadata[0].namespace]
  token_ttl                        = 3600
  token_policies                   = ["vault_configurator"]
}

resource "kubernetes_service_account" "terraform" {
  metadata {
    annotations = {
      created-by = "terraform:bootstrap"
    }

    name = "terraform"
    namespace = data.kubernetes_namespace.vault_configurator.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding" "terraform_state_manager" {
  metadata {
    annotations = {
      created-by = "terraform:bootstrap"
    }

    name = "TerraformStateManager"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }
  #role_ref {
  #  api_group = "rbac.authorization.k8s.io"
  #  kind = "Role"
  #  name = "TerraformStateManager"
  #}

  subject {
    kind = "ServiceAccount"
    name = kubernetes_service_account.terraform.metadata[0].name
    namespace = kubernetes_service_account.terraform.metadata[0].namespace
  }
}
