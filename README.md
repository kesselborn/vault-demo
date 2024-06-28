# Vault demo

<!--toc:start-->

- [Vault demo](#vault-demo)
  - [Usage](#usage)
  - [Prerequisits](#prerequisits)
  - [Demo script](#demo-script)
    - [Install vault cli tool](#install-vault-cli-tool)
    - [Launch kubernetes cluster](#launch-kubernetes-cluster)
    - [Install k8s stuff](#install-k8s-stuff)
    - [Create tunnel to Kubernetes-Cluster](#create-tunnel-to-kubernetes-cluster)
    - [Initialize Vault](#initialize-vault)
    - [Set Vault Token](#set-vault-token)
    - [Unseal Vault](#unseal-vault)
    - [Enable Key-Value Storage](#enable-key-value-storage)
    - [Create a user with username-password login](#create-a-user-with-username-password-login)
    - [Enable database backends](#enable-database-backends)
      - [Enable mariadb](#enable-mariadb)
      - [Enable postgres](#enable-postgres)
    - [Demonstrate dynamic secrets](#demonstrate-dynamic-secrets)
      - [mariadb](#mariadb)
      - [postgres](#postgres)
    - [Enable and use Kubernetes-Auth](#enable-and-use-kubernetes-auth)
  - [Alternative: use Vault-k8s](#alternative-use-vault-k8s)
    - [Set permissions](#set-permissions)
    - [Start demo apps with vault injects](#start-demo-apps-with-vault-injects)
  - [Mongodb](#mongodb)
  <!--toc:end-->

This is a little vault demo. It uses Kind (Kubernetes in Docker) in order spin
up vault, mariadb and a demo app. The demo sets up a vault and enables several
secret and auth backends. Finally, it demos how to deploy an app in Kubernetes
using dynamic secrets for the mariadb backen. This README has just the steps to
execute (an elaborate note-to-self) and not a lot of explainations.

## Usage

There is a `demo` program for all sub commands ... just follow the script below.
If you see a 💤, press enter to continue. It shows you the command and waits
before continuing so that you can talk about the commands executed

## Prerequisits

In order to run the demo, the script expects the following evironment:

- a running docker installation + access to use docker
- the kubernetes cli tool `kubectl`
- for vault-k8s: install [Helm 3](https://helm.sh/docs/intro/install/)

## Demo script

### Install vault cli tool

First you have to install the vault cli command -- if you are on mac, simply
call

```sh
./demo install_vault
```

### Launch kubernetes cluster

If you don't have a kubernetes cluster, you can create one with the demo script
using kind (Kubernetes in Docker)

```sh
./demo launch_kind_cluster
export KUBECONFIG=$PWD/kind.kubeconfig # tell kubectl to use this cluster
```

### Install k8s stuff

Install vault, mariadb and the demo app into the kubernetes cluster (it
basically applies vault.yaml, mariadb.yaml, demo-app.yaml)

```sh
./demo install_k8s_pods
while sleep 2; do clear; kubectl get pods; done
```

if you are in an offline situation and you have the docker images mariadb and
vault locally available, you can upload then into your kind cluster by executing

```sh
./demo load_image hashicorp/vault
./demo load_image mariadb
./demo load_image postgres
./demo load_image mongo
```

wait until all pods are in state running:

```sh
$  kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
demo-app-7758748d8f-59c8m   3/3     Running   0          99s
mariadb-6955947fc4-7mm74    1/1     Running   0          98s
mongodb-64488f6f5d-rf854    1/1     Running   0          98s
postgres-7999fc687c-lp9bv   1/1     Running   0          98s
vault-755d667778-v56nh      1/1     Running   0          98s
```

### Create tunnel to Kubernetes-Cluster

In order to be able to talk to the vault within the kubernetes cluster, we
need to create a tunnel. Open another terminal and execute (within the demo
folder)

```sh
export KUBECONFIG=$PWD/kind.kubeconfig # tell kubectl to use this cluster
kubectl port-forward svc/vault 8200:8200
```

### Initialize Vault

**GPG**: if you want to use gpg for encrypting any keys, do the following
(then, scripts below won't work anymore):

```sh
# export public key
gpg -o /tmp/gpg.pub --export EMAIL_ADDRESS

# decrypt blob
echo 'BLOB'|base64 -d|gpg -d

```

go back to your original terminal and initialize vault with

or go to <http://localhost:8200>

```sh
./demo init_vault
export VAULT_ADDR=http://localhost:8200
vault status
```

this should produce something like

```sh
$ cat keys Unseal Key 1: CcGugB9WurkLD4AcPVB7IcLktg7hUXkKsuqCRhyLTCWX
Unseal Key 2: KmEUc1dEVi7ibupfU5F9nBiU9JG/5+0ALh9hDgz/Wma/ Unseal Key 3:
SOUV4ebyO/T2Hbep8DNaUSYoGFBBusL3o2ErNNaJ4Sb7 Unseal Key 4:
6LiFvNAqL1HgUUn522DCy0lqPwTmZPJiCMCq3Qe8BLTd Unseal Key 5:
mOdtim0NDx457phMfGo722rQTNp7WLNj6/TlPeeuCxGR

Initial Root Token: hvs.9lZMqX6jN7ipHOr5nVttN7f4

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed, restarted,
or stopped, you must supply at least 3 of these keys to unseal it before it can
start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

this will show you the output that vault will give you and store this output in
a file called `keys` for later usage. Alternatively, go to <http://localhost:8200/ui>

### Set Vault Token

In order to talk to vault, we need a token which can be set with the env var
`VAULT_TOKEN` and the vault address. Set these env variables by executing

```sh
eval $(./demo set_vault_env) vault status
```

- execute `vault status`

### Unseal Vault

Unseal vault with the given unsealing keys (the demo script uses the `keys`
file for this)

```sh
./demo unseal_vault 1
./demo unseal_vault 2
./demo unseal_vault 3
```

alternatively, unseal in the browser under <http://localhost:8200>

### Enable Key-Value Storage

Enable the key/value secrets storage, set a value and retrieve it from the
key value store

```sh
./demo enable_kv_secret_backend
vault kv put kv/foo foo=bar bar=baz
vault kv get kv/foo
vault kv get --format=json kv/foo
```

### Create a user with username-password login

- create a user called `foo` with creds `foo/bar`
- try to read kv (which is denied)
- apply policy
- try to get value again and it works

```sh
./demo create_vault_user
vault login -method=userpass username=foo password=bar
```

remember the token in an env var and try to read a secret (**this should fail**)

```sh
USER_TOKEN=$(vault login -token-only -method=userpass username=foo password=bar)
VAULT_TOKEN=$USER_TOKEN vault kv get kv/foo
```

apply a policy, which give the user the right to read this secret (**this should work**:)

```sh
cat kv-foo.hcl
vault policy write kv-foo kv-foo.hcl
VAULT_TOKEN=$USER_TOKEN vault kv get kv/foo # should work now
```

### Enable database backends

#### Enable mariadb

```sh
./demo enable_mariadb
vault read mariadb/creds/testdb-rw
vault read mariadb/creds/testdb-rw # username / password differs from first request
```

#### Enable postgres

```sh
./demo enable_postgres
vault read postgres/creds/testdb-rw
vault read postgres/creds/testdb-rw # username / password differs from first request
```

### Demonstrate dynamic secrets

#### mariadb

Open other terminal, set kubeconfig to `$PWD/kind.kubeconfig` if you use the `kind`-installation,
jump into **mariadb** pod and show users

```sh
export KUBECONFIG=$PWD/kind.kubeconfig # (is you don't use your own k8s cluster)
MARIADB_POD=$(kubectl get pod -l app=mariadb -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $MARIADB_POD /bin/sh
```

once in the pod execute:

```sh
while true; do clear; date; \
  echo "select user from user;"|mariadb -uroot -pmypass -Dmysql; sleep 2; done
```

Back in your original terminal execute and see, how new mariadb users pop up
and vanish after 10 seconds

```sh
while sleep 2; do vault read -format=json mariadb/creds/testdb-rw; done
```

#### postgres

in one terminal, force the creation of users

```sh
while sleep 2; do vault read -format=json postgres/creds/testdb-rw; done
```

```sh
while sleep 2; do \
  kubectl exec -it deploy/postgres -- /bin/sh -c "echo '\\du'|psql -U postgres"; done
```

### Enable and use Kubernetes-Auth

Enable kubernetes authentication backend

```sh
  ./demo enable_k8s_auth
```

### Manually authenticate with Kubernetes auth

Set permissions and jump into app container

```sh
# give kubernetes default/default right to read db creds
vault policy write testdb-ro testdb-ro.hcl
POD=$(kubectl get pod -l app=demo-app -o jsonpath="{.items[0].metadata.name}")
kubectl cp vault-agent.hcl $POD:/tmp

kubectl exec -it $POD /bin/sh

# in the container, execute:
apk add --no-cache curl jq
cat /var/run/secrets/kubernetes.io/serviceaccount/token
export JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token )

export VAULT_ADDR=http://vault:8200
curl -s -XPOST -d '{"role": "test", "jwt":"'$JWT'"}' http://vault:8200/v1/auth/kubernetes/login

# does not work:
vault read database/creds/testdb-ro

export VAULT_TOKEN=$(curl -s -XPOST -d '{"role": "test", "jwt":"'$JWT'"}' \
                        http://vault:8200/v1/auth/kubernetes/login|jq -r ".auth.client_token")

# now it works
vault read mariadb/creds/testdb-ro

vault agent -config /tmp/vault-agent.hcl
```

## Alternative: use Vault-k8s

This example [installs vault with helm](https://github.com/hashicorp/vault-helm) and injects [vault-agent](https://www.vaultproject.io/docs/agent) automatically
using [vault-k8s](https://github.com/hashicorp/vault-k8s)

### Prepare cluster

- [Install vault cli tool](#install-vault-cli-tool)
- [Launch kubernetes cluster](#launch-kubernetes-cluster)
- [Install k8s stuff](#install-k8s-stuff)

### Replace Vault by the Vault operator

```~~
kubectl delete -f k8s-vault.yaml
helm install vault --values vault-values.yaml \
  https://github.com/hashicorp/vault-helm/archive/refs/tags/v0.28.0.tar.gz
```

### Setup Vault and the rest

... wait until Vault is available

- [Create tunnel to Kubernetes-Cluster](#create-tunnel-to-kubernetes-cluster)
- [Initialize Vault](#initialize-vault)
- [Set Vault Token](#set-vault-token)
- [Unseal Vault](#unseal-vault)
- [Enable and use Kubernetes-Auth](#enable-and-use-kubernetes-auth)
- [Enable database backends](#enable-database-backends)

### Set permissions

Allow Kubernetes authorized user access to db:

````sh
# give kubernetes default/default right to read db creds ```
vault policy write testdb-ro testdb-ro.hcl
````

### Start demo apps with vault injects

```sh
kubectl apply -f demo-app-inject-mariadb.yaml
kubectl apply -f demo-app-inject-postgres.yaml
```

check the logs for users created by the vault-agent sidecar (using the same
sidecar)

```sh
kubectl logs -f deploy/demo-app-inject-mariadb
kubectl logs -f deploy/demo-app-inject-postgres
```

## Mongodb

```sh
./demo enable_mongodb vault read database/creds/mongo-rw

kubectl exec -it deploy/mongodb -- mongosh --username '...' --password '...'
```
