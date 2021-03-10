locals {
  name = "project1"
}

resource "vault_mount" "project1_db" {
  path        = "/${local.name}/${local.name}-db"
  type        = "database"
}

resource "vault_database_secret_backend_connection" "project1_db" {
  backend       = vault_mount.project1_db.path
  name          = local.name
  allowed_roles = ["${local.name}-db-*"]

  mysql {
    connection_url = "{{username}}:{{password}}@tcp(mysql.default:3306)/"
  }

  data = {
    username = "root"
    password = "mypass"
  }
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

output "project1_database" {
  value = {
    description = "database used for ${local.name}",
    backend = vault_mount.project1_db.path,
    db_name = vault_database_secret_backend_connection.project1_db.name,
    allowed_roles = vault_database_secret_backend_connection.project1_db.allowed_roles[0]
    project_db_ro_creds_path = "${vault_database_secret_backend_role.project1_db_ro.backend}/creds/${vault_database_secret_backend_role.project1_db_ro.name}",
    project_db_ro_policy = vault_policy.project1_db_ro.name
  }
}
