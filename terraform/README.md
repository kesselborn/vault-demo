# Howto

## Bootstrapping

Execute the following commands -- this demo expects that the cli tools `kubectl` and `vault` are available.

    # in parent dir: start cluster and set a few env variables
    ./demo launch_kind_cluster
    ./demo install_kubernetes_apps
    export KUBECONFIG=$PWD/kind.kubeconfig
    
    # make vault available locally
    kubectl -n default port-forward svc/vault 8200:8200 2>&1 1 > vault.log &
    
    # init and unseal vault
    ./demo init_vault
    ./demo unseal_vault 1
    ./demo unseal_vault 2
    ./demo unseal_vault 3
    
    # set vault env vars
    eval $(./demo set_vault_env)
    
    # in the terraform directory
    kubectl create namespace vault-configurator && \
    terraform init && \
    terraform apply -target=vault_mount.admin -auto-approve && \
    vault secrets list

You will now have a Kubernetes-Cluster with an installed Vault + exported env variables that grand admin-level access to Kubernetes and Vault. The terraform command only executed one part of the recipe: it mounted a generic secrets mount to `admin/secrets/` so admins can already manually add secrets to some defined locations.

## Deploy terraform plan

The demo is setting up access to a mysql database -- before the first run can complete, this secret has to be set. This would be the way how the process later can / could work:

- a developer creates a pull request which gets reviewed
- the terraform code expects database root passwords to be available at a certain location under `/admin/secrets` which are not accessible by the users
- after the secrets have been set by admins & the pull request was approved, terraform is automatically executed
- root-passwords from a database are rotated immediately on the terraform run
- other secrets should be pre-filled with dummy-values in the terraform code and ignored using the lifecycle-command from terraform. Secret values are then set by developers after the first terraform run. As the are ignored, only the initial dummy value will end up in the state file

Run terraform plan and fix the errors -- usually missing credentials that need to be set, call `terraform apply` afterwards

    terraform plan # this should complain about missing secrets
    vault write admin/secrets/project1-db username=root password=mypass
    terraform apply



## Runnig terraform in Kubernetes

Build the docker image and load it into our local kubernetes cluster:

```
docker build -t terraform-runner .
(cd ..; ./demo load_image terraform-runner)
kubectl apply -f terraform-runner.yaml && watch kubectl -n vault-configurator get jobs,pods
```

![terraform run in kubernetes](k8s-terraform-run.svg)



## Destroying

    terraform destroy && \
    ../demo reset_mysql_passwd && \
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

