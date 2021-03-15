# Howto

## Bootstrapping

    kubectl create namespace vault-configurator && \
    terraform init && \
    terraform apply -target=vault_mount.admin -auto-approve

## Deploy terraform plan

Run terraform plan and fix the errors -- usually missing credentials that need to be set, call `terraform apply` afterwards

    terraform plan && terraform apply

## Destroying

    terraform destroy && \
    kubectl delete namespace vault-configurator


## Debugging errors


    Error: no secret found at "admin/secrets/project1-db"

      on team1.tf line 10, in data "vault_generic_secret" "project1_db":
      10: data "vault_generic_secret" "project1_db" {



      on team1.tf line 24, in resource "vault_database_secret_backend_connection" "project1_db":
      24:     password = data.vault_generic_secret.project1_db.data["username"]
        |----------------
        | data.vault_generic_secret.project1_db.data is map of string with 1 element

    The given key does not identify an element in this collection value.


# main provider block with no namespace
# in order to run terraform, the following env vars must be set:
# - VAULT_ADDR: address under which vault is exposed
# - VAULT_TOKEN: a valid token to speak to vault
# - KUBE_CONFIG_PATH: points to a valid kubernetes config

