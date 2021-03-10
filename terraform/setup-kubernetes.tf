provider "kubernetes" {
}

resource "kubernetes_namespace" "vault_configurator" {
  metadata {
    annotations = {
      created-by = "terraform:bootstrap"
    }

    name = "vault-configurator"
  }
}

resource "kubernetes_service_account" "vault_auth" {
  metadata {
    annotations = {
      created-by = "terraform:bootstrap"
    }

    name = "vault-auth"
    namespace = kubernetes_namespace.vault_configurator.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding" "vault_auth_token_reviewer" {
  metadata {
    annotations = {
      created-by = "terraform:bootstrap"
    }

    name = "vault-auth-token-reviewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "system:auth-delegator"
  }

  subject {
    kind = "ServiceAccount"
    name = kubernetes_service_account.vault_auth.metadata[0].name
    namespace = kubernetes_namespace.vault_configurator.metadata[0].name
  }
}

data "kubernetes_secret" "vault_auth_token" {
  metadata {
    name = kubernetes_service_account.vault_auth.default_secret_name
    namespace = kubernetes_service_account.vault_auth.metadata[0].namespace
  }
}

resource "kubernetes_service_account" "terraform" {
  metadata {
    annotations = {
      created-by = "terraform:bootstrap"
    }

    name = "terraform"
    namespace = kubernetes_namespace.vault_configurator.metadata[0].name
  }
}

resource "kubernetes_role" "terraform_state_manager" {
  metadata {
    annotations = {
      created-by = "terraform:bootstrap"
    }

    name = "TerraformStateManager"
    namespace = kubernetes_namespace.vault_configurator.metadata[0].name
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["tfstate-default-state"]
    verbs          = ["get", "list", "watch", "create", "update", "delete"]
  }

}

resource "kubernetes_role_binding" "terraform_state_manager" {
  metadata {
    annotations = {
      created-by = "terraform:bootstrap"
    }

    name = "TerraformStateManager"
    namespace = kubernetes_namespace.vault_configurator.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "Role"
    name = "TerraformStateManager"
  }

  subject {
    kind = "ServiceAccount"
    name = kubernetes_service_account.terraform.metadata[0].name
    namespace = kubernetes_service_account.terraform.metadata[0].namespace
  }
}
