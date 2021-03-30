locals {
  name = "project1"
  path = "/projects/project1"
}

resource "vault_mount" "project1_db" {
  path        = "${local.path}/db"
  type        = "database"
}

# we expect that the database user credential values are available under the
# secret 'admin/secrets/project1-db' using the keys 'username' and 'password'
# vault write admin/secrets/project1-db password=PASSWORD username=USERNAME
data "vault_generic_secret" "project1_db" {
  path = "admin/secrets/project1-db"
}

resource "vault_database_secret_backend_connection" "project1_db" {
  backend       = vault_mount.project1_db.path
  name          = local.name
  allowed_roles = ["${local.name}-db-*"]

  mysql {
    connection_url = "{{username}}:{{password}}@tcp(mysql.default:3306)/"
  }

  data = {
    username = data.vault_generic_secret.project1_db.data["username"]
    password = data.vault_generic_secret.project1_db.data["password"]
  }
}

resource "vault_generic_endpoint" "rotate_initial_project1_db_pw" {
  depends_on           = [vault_database_secret_backend_connection.project1_db]
  path                 = "${vault_database_secret_backend_connection.project1_db.backend}/rotate-root/${vault_database_secret_backend_connection.project1_db.name}"
  disable_read   = true
  disable_delete = true

  data_json = "{}"
}


resource "vault_database_secret_backend_role" "project1_db_ro" {
  backend             = vault_mount.project1_db.path
  db_name             = vault_database_secret_backend_connection.project1_db.name
  name                = "${local.name}-db-ro"
  creation_statements = ["CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';"]
}

resource "vault_policy" "project1_db_ro" {
  name = "${local.name}-db-ro"

  policy = <<EOT
path "${vault_mount.project1_db.path}/creds/${vault_database_secret_backend_role.project1_db_ro.name}" {
  capabilities = ["read"]
}
  EOT
}

resource "kubernetes_namespace" "project1" {
  metadata {
    annotations = {
      created-by = "terraform"
    }

    name = "project1"
  }
}


resource "kubernetes_service_account" "project1" {
  metadata {
    annotations = {
      created-by = "terraform"
    }

    name = "project1"
    namespace = kubernetes_namespace.project1.metadata[0].name
  }
}

resource "vault_kubernetes_auth_backend_role" "project" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "project1-k8s-service-account"
  bound_service_account_names      = [kubernetes_service_account.project1.metadata[0].name]
  bound_service_account_namespaces = [kubernetes_namespace.project1.metadata[0].name]
  token_ttl                        = 3600
  token_policies                   = ["project1-k8s-service-account"]
}

resource "vault_mount" "project1_secrets" {
  path        = "${local.path}/secrets"
  type        = "generic"
  description = "static secrets for project1"
}

resource "vault_generic_secret" "example" {
  path = "${vault_mount.project1_secrets.path}/foo"
  disable_read = true

  data_json = <<EOT
{
  "foo": "foobar3333"
}
EOT
#  lifecycle {
#    ignore_changes = [
#      data_json,
#    ]
#  }


}

resource "vault_policy" "project1_k8s_service_account" {
  name = "project1-k8s-service-account"
  policy = <<EOT

path "${local.path}/*" {
  capabilities = ["read", "list"]
}

EOT
}

resource "vault_policy" "project1_dev" {
  name = "project1-dev"
  policy = <<EOT

path "${vault_mount.project1_secrets.path}" {
  capabilities = ["create", "update"]
}

EOT
}


output "project1" {
  value = {
    description = "database used for ${local.name}"
    backend = vault_mount.project1_db.path
    db_name = vault_database_secret_backend_connection.project1_db.name
    allowed_roles = vault_database_secret_backend_connection.project1_db.allowed_roles[0]
    policy_for_service_account = vault_policy.project1_k8s_service_account.name
    secrets_backend_path = vault_mount.project1_secrets.path
    project_db_ro_creds_path = "${vault_database_secret_backend_role.project1_db_ro.backend}/creds/${vault_database_secret_backend_role.project1_db_ro.name}"
    project_db_connection = vault_database_secret_backend_connection.project1_db.backend
    project_db_ro_policy = vault_policy.project1_db_ro.name
    project_db_root_credentials_username = "${data.vault_generic_secret.project1_db.path}['username']"
    project_db_root_credentials_password = "${data.vault_generic_secret.project1_db.path}['password']"
  }
}
