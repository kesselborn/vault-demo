# Vault demo

This is a little vault demo. It uses Kind (Kubernetes in Docker) in order spin up vault, mariadb and a demo app.
The demo sets up a vault and enables several secret and auth backends. Finally, it demos how to deploy an app in Kubernetes using dynamic secrets for the mariadb backen.
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

3. install vault, mariadb and the demo app into the kubernetes cluster (it basically applies vault.yaml, mariadb.yaml, demo-app.yaml)

       ./demo install_k8s_pods
       watch kubectl get pods

  if you are in an offline situation and you have the docker images mariadb and vault locally available, you can upload then into your kind cluster by executing

       ./demo load_image hashicorp/vault
       ./demo load_image mariadb
       ./demo load_image postgres
       ./demo load_image mongo

   wait until all pods are in state running:

       $ kubectl get pods
       demo-app-84b77c7f9-zdpd4   2/2     Running   0          3m19s
       mariadb-f998d4f87-m8wf8    1/1     Running   0          3m19s
       vault-5558555bd8-7cppv     1/1     Running   0          32s

4. in order to be able to talk to the vault within the kubernetes cluster, we need to create a tunnel. Open another terminal and execute (within the demo folder)

       export KUBECONFIG=$PWD/kind.kubeconfig # tell kubectl to use this cluster
       kubectl port-forward svc/vault 8200:8200

5. **GPG**: if you want to use gpg for encrypting any keys, do the following (then, scripts below won't work anymore): 

   ```
   # export public key
   gpg -o /tmp/gpg.pub --export EMAIL_ADDRESS
   
   # decrypt blob
   echo 'BLOB'|base64 -d|gpg -d
   ```

   go back to your original terminal and initialize vault with

   or go to http://localhost:8200

       ./demo init_vault
       export VAULT_ADDR=http://localhost:8200
       vault status

   ```
   $ cat keys 
   Unseal Key 1: CcGugB9WurkLD4AcPVB7IcLktg7hUXkKsuqCRhyLTCWX
   Unseal Key 2: KmEUc1dEVi7ibupfU5F9nBiU9JG/5+0ALh9hDgz/Wma/
   Unseal Key 3: SOUV4ebyO/T2Hbep8DNaUSYoGFBBusL3o2ErNNaJ4Sb7
   Unseal Key 4: 6LiFvNAqL1HgUUn522DCy0lqPwTmZPJiCMCq3Qe8BLTd
   Unseal Key 5: mOdtim0NDx457phMfGo722rQTNp7WLNj6/TlPeeuCxGR
   
   Initial Root Token: hvs.9lZMqX6jN7ipHOr5nVttN7f4
   
   Vault initialized with 5 key shares and a key threshold of 3. Please securely
   distribute the key shares printed above. When the Vault is re-sealed,
   restarted, or stopped, you must supply at least 3 of these keys to unseal it
   before it can start servicing requests.
   
   Vault does not store the generated root key. Without at least 3 keys to
   reconstruct the root key, Vault will remain permanently sealed!
   
   It is possible to generate new unseal keys, provided you have a quorum of
   existing unseal keys shares. See "vault operator rekey" for more information.
   ```

   

   this will show you the output that vault will give you and store this output in a file called `keys` for later usage. Alternatively, go to http://localhost:8200/ui 

   

6. in order to talk to vault, we need a token which can be set with the env var `VAULT_TOKEN` and the vault address. Set these env variables by executing

       eval $(./demo set_vault_env)
       vault status

7. execute `vault status`

8. go to http://localhost:8200/ui show that vault is sealed


6. unseal vault with the given unsealing keys (the demo script uses the `keys` file for this)

        ./demo unseal_vault 1
        ./demo unseal_vault 2
        ./demo unseal_vault 3  # alternatively, do this in the browser


8. enable the key/value secrets storage, set a value and retrieve it from the key value store

        ./demo enable_kv_secret_backend
        vault kv put kv/foo foo=bar bar=baz
        vault kv get kv/foo
        vault kv get --format=json kv/foo

9. 
  - create a user called `foo` with creds `foo/bar`
  - try to read kv (which is denied)
  - apply policy
  - try to get value again and it works


        ./demo create_vault_user
        vault login -method=userpass username=foo password=bar # shows a login
        export USER_TOKEN=$(vault login -token-only -method=userpass username=foo password=bar)
        VAULT_TOKEN=$USER_TOKEN vault kv get kv/foo            # this will fail with a permission denied
      
        cat kv-foo.hcl
        vault policy write kv-foo kv-foo.hcl
        VAULT_TOKEN=$USER_TOKEN vault kv get kv/foo            # should work now

10. enable mariadb backend

        ./demo enable_mariadb
        vault read database/creds/testdb-rw
        vault read database/creds/testdb-rw # username / password differs from first request
    

**OR** enable postgres backend

        ./demo enable_postgres
        vault read database/creds/testdb-rw
        vault read database/creds/testdb-rw # username / password differs from first request

11. open other terminal, set kubeconfig to `$PWD/kind.kubeconfig`, jump into **mariadb** pod and show users

        export KUBECONFIG=$PWD/kind.kubeconfig # tell kubectl to use this cluster
        MARIADB_POD=$(kubectl get pod -l app=mariadb -o jsonpath="{.items[0].metadata.name}")
        kubectl exec -it $MARIADB_POD /bin/sh
        # once in the pod execute:
        while true; do clear; date; echo "select user from user;"|mariadb -uroot -pmypass -Dmysql; sleep 2; done
        
        # back in your original terminal execute and see, how new mariadb users pop up and vanish after 10 seconds
        vault read -format=json database/creds/testdb-rw
        vault read -format=json database/creds/testdb-rw
        vault read -format=json database/creds/testdb-rw
    

**postgres**

```sh
kubectl exec -it deploy/postgres /bin/bash

while sleep 5; do
kubectl exec -it deploy/postgres -- /bin/sh -c "echo '\du'|psql -U postgres"; done
```

12. enable kubernetes authentication backend

        ./demo enable_k8s_auth

13. jump into the vault agent pod and start vault agent with `vault-agent.hcl` config:

        vault policy write testdb-ro testdb-ro.hcl # give kubernetes default/default right to read db creds
        POD=$(kubectl get pod -l app=demo-app -o jsonpath="{.items[0].metadata.name}")
        kubectl cp vault-agent.hcl $POD:/tmp
        
        kubectl exec -it $POD /bin/sh
        
        apk add --no-cache curl jq
        cat /var/run/secrets/kubernetes.io/serviceaccount/token
        export JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token )
        
        export VAULT_ADDR=http://vault:8200
        curl -s -XPOST -d '{"role": "test", "jwt":"'$JWT'"}' http://vault:8200/v1/auth/kubernetes/login
        
        # does not work
        vault read database/creds/testdb-ro
        
        export VAULT_TOKEN=$(curl -s -XPOST -d '{"role": "test", "jwt":"'$JWT'"}' http://vault:8200/v1/auth/kubernetes/login|jq -r ".auth.client_token")
        
        # now it works
        vault read database/creds/testdb-ro
        
        vault agent -config /tmp/vault-agent.hcl


```sh
create table "testdb" (foo int);
insert into testdb (foo) values (23);
```

## Alternative: use Vault-k8s

This example [installs vault with helm](https://github.com/hashicorp/vault-helm) and injects [vault-agent](https://www.vaultproject.io/docs/agent) automatically using [vault-k8s](https://github.com/hashicorp/vault-k8s) 

1. cleanup cluster (or if you start from here, follow steps 1 and 2 above)

````
kubectl delete -f k8s-vault.yaml; kubectl delete -f k8s-demo-app.yaml
````

2. run vault again using helm chart

```sh
   helm install vault \
       --values vault-values.yaml \
       https://github.com/hashicorp/vault-helm/archive/refs/tags/v0.28.0.tar.gz
```

3. start mysql

```
   kubectl apply -f k8s-mariadb.yaml
   kubectl apply -f k8s-postgres.yaml
```

4. folllow steps 4-7 above to initiallize vault

5. enable mariadb **OR** postgres backend

```sh
./demo enable_mariadb
./demo enable_postgres
```

6. enable kubernetes authentication backend

```sh
./demo enable_k8s_auth
```

7. jump into the vault agent pod and start vault agent with `vault-agent.hcl` config:

```sh
 vault policy write testdb-ro testdb-ro.hcl # give kubernetes default/default right to read db creds
```

8. start the mariadb **OR** postgres demo-app, containing annotations that configure the vault-agent sidecar deployment 

```sh
   kubectl apply -f demo-app-inject-mariadb.yaml
   kubectl apply -f demo-app-inject-postgres.yaml
```

check the logs for users created by the vault-agent sidecar (using the same sidecar)

```sh
   DEMO_POD=$(kubectl get pod -l app=demo-app-inject -o jsonpath="{.items[0].metadata.name}")
   kubectl logs -f $DEMO_POD app
```

## Mongodb

```sh
./demo enable_mongodb
vault read database/creds/mongo-rw

kubectl exec -it deploy/mongodb -- mongosh --username '...' --password '...' 
```

