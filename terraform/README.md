# Howto

## Bootstrapping

    terraform init -backend-config=namespace=default -reconfigure
    terraform apply -target=kubernetes_namespace.vault_configurator -target=vault_mount.admin -auto-approve
    terraform init -backend-config=namespace=vault-configurator -force-copy
    kubectl -n default delete secret tfstate-default-state

## Deploy terraform plan

    terraform apply

## Destroying

    terraform init -backend-config=namespace=default
    terraform destroy
    kubectl -n default delete secret tfstate-default-state

# main provider block with no namespace
# in order to run terraform, the following env vars must be set:
# - VAULT_ADDR: address under which vault is exposed
# - VAULT_TOKEN: a valid token to speak to vault
# - KUBE_CONFIG_PATH: points to a valid kubernetes config

