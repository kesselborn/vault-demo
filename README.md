# Vault demo

This is a little vault demo. It uses Kind (Kubernetes in Docker) in order spin up vault, mysql and a demo app.
The demo sets up a vault and enables several secret and auth backends. Finally, it demos how to deploy an app in Kubernetes using dynamic secrets for the mysql backen.
This README has just the steps to execute (an elaborate note-to-self) and not a lot of explainations.

# Usage

There is a `demo` program for all sub commands ... just follow the script below. If you see a 💤, press enter to continue. It shows you the command and waits before continuing so that you can talk about the commands executed

## Prerequisits

In order to run the demo, the script expects the following evironment:

- a running docker installation + access to use docker
- the kubernetes cli tool `kubectl`
- for vault-k8s: install [Helm 3](https://helm.sh/docs/intro/install/)

# Demo script:

1. first you have to install the vault cli command -- if you are on mac, simply call `./demo install_vault`

2. for our demo, we will use Kubernetes in Docker. The demo script assumes you have docker running and the current user is allowed to use docker. Start the Kubernetes cluster with: 

       ./demo launch_kind_cluster
       export KUBECONFIG=$PWD/kind.kubeconfig # tell kubectl to use this cluster

3. install vault, mysql and the demo app into the kubernetes cluster (it basically applies vault.yaml, mysql.yaml, demo-app.yaml)

       ./demo install_k8s_pods
       kubectl get pods

  if you are in an offline situation and you have the docker images mysql and vault locally available, you can upload then into your kind cluster by executing

       ./demo load_image vault
       ./demo load_image mysql

   wait until all pods are in state running:

       $ kubectl get pods
       demo-app-84b77c7f9-zdpd4   2/2     Running   0          3m19s
       mysql-f998d4f87-m8wf8      1/1     Running   0          3m19s
       vault-5558555bd8-7cppv     1/1     Running   0          32s

4. in order to be able to talk to the vault within the kubernetes cluster, we need to create a tunnel. Open another terminal and execute (within the demo folder)

       export KUBECONFIG=$PWD/kind.kubeconfig # tell kubectl to use this cluster
       kubectl port-forward svc/vault 8200:8200

5. go back to your original terminal and initialize vault with

      ./demo init_vault

   this will show you the output that vault will give you and store this output in a file called `keys` for later usage.

6. unseal vault with the given unsealing keys (the demo script uses the `keys` file for this)

       ./demo unseal_vault 1
       ./demo unseal_vault 2
       ./demo unseal_vault 3

7. in order to talk to vault, we need a token which can be set with the env var `VAULT_TOKEN` and the vault address. Set these env variables by executing

       eval $(./demo set_vault_env)
       vault status

8. enable the key/value secrets storage, set a value and retrieve it from the key value store

       ./demo enable_kv_secret_backend
        vault kv put kv/foo foo=bar bar=baz
        vault kv get kv/foo

9. create a user called foo with creds foo/bar, try to read kv (which is denied), apply policy, try to get value again and it works

       ./demo create_vault_user
        vault login -method=userpass username=foo password=bar # shows a login
        export USER_TOKEN=$(vault login -token-only -method=userpass username=foo password=bar)
        VAULT_TOKEN=$USER_TOKEN vault kv get kv/foo            # this will fail with a permission denied

        cat kv-foo.hcl
        vault policy write kv-foo kv-foo.hcl
        VAULT_TOKEN=$USER_TOKEN vault kv get kv/foo            # should work now

10. enable mysql backend

        ./demo enable_mysql
        vault read database/creds/testdb-rw
        vault read database/creds/testdb-rw # username / password differs from first request

11. open other terminal, set kubeconfig to `$PWD/kind.kubeconfig`, jump into mysql pod and show users

        MYSQL_POD=$(kubectl get pod -l app=mysql -o jsonpath="{.items[0].metadata.name}")
        kubectl exec -it $MYSQL_POD /bin/sh
        # once in the pod execute:
        while true; do clear; date; echo "select user from user;"|mysql -uroot -pmypass -Dmysql; sleep 2; done

        # back in your original terminal execute and see, how new mysql users pop up and vanish after 10 seconds
        vault read database/creds/testdb-rw
        vault read database/creds/testdb-rw
        vault read database/creds/testdb-rw

12. enable kubernetes authentication backend

        ./demo enable_k8s_auth

13. jump into the vault agent pod and start vault agent with `vault-agent.hcl` config:

        vault policy write testdb-ro testdb-ro.hcl # give kubernetes default/default right to read db creds
        POD=$(kubectl get pod -l app=demo-app -o jsonpath="{.items[0].metadata.name}")
        kubectl cp vault-agent.hcl $POD:/tmp

        kubectl exec -it $POD /bin/sh

        apk add --no-cache curl jq
        export JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token )
        curl -XPOST -d '{"role": "test", "jwt":"'$JWT'"}' http://vault:8200/v1/auth/kubernetes/login

        export VAULT_ADDR=http://vault:8200
        export VAULT_TOKEN=$(curl -s -XPOST -d '{"role": "test", "jwt":"'$JWT'"}' http://vault:8200/v1/auth/kubernetes/login|jq -r ".auth.client_token")
        vault read database/creds/testdb-ro


## Alternative: use Vault-k8s

This example [installs vault with helm](https://github.com/hashicorp/vault-helm) and injects [vault-agent](https://www.vaultproject.io/docs/agent) automatically using [vault-k8s](https://github.com/hashicorp/vault-k8s) 

1. cleanup cluster (or if you start from here, follow steps 1 and 2 above)

````
   kubectl delete -f vault.yaml demo-app.yaml
````

2. run vault again using helm chart

   ```sh
   helm install vault \
       --values vault-values.yaml \
       https://github.com/hashicorp/vault-helm/archive/v0.5.0.tar.gz
   ```
```

3. start mysql

```
   kubectl apply -f mysql.yaml
   ```

4. folllow steps 4-7 above to initiallize vault

5. enable mysql backend

   ```sh
   ./demo enable_mysql
   ```

6. enable kubernetes authentication backend

       ./demo enable_k8s_auth

7. jump into the vault agent pod and start vault agent with `vault-agent.hcl` config:

   ```sh
   vault policy write testdb-ro testdb-ro.hcl # give kubernetes default/default right to read db creds
   ```

8. start the demo-app, containing annotations that configure the vault-agent sidecar deployment 

   ```sh
   kubectl apply -f demo-app-inject.yaml
   ```

   check the logs for users created by the vault-agent sidecar (using the same sidecar)

   ```sh
   DEMO_POD=$(kubectl get pod -l app=demo-app-inject -o jsonpath="{.items[0].metadata.name}")
   kubectl logs $DEMO_POD app
   ```

