pid_file = "./pidfile"

vault {
  address = "http://vault:8200"
}

auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"

    config = {
      role = "test"
    }
  }

  sink "file" {
    config = {
      path = "/tmp/vault-token"
    }
  }
}

template {
  destination = "/config/db.properties"

  contents = <<EOH
  {{- with secret "database/creds/testdb-ro" }}
db.username={{ .Data.username }}
db.password={{ .Data.password }}
  {{ end }}
EOH
}

template {
  destination = "/config/mysql-script"
  perms       = 0755

  contents = <<EOH
  {{- with secret "database/creds/testdb-ro" }}
for _ in $(seq 1 50); do echo; done
date
set -x
echo "show databases;"|mysql -u{{ .Data.username }} -p{{ .Data.password }} -Dtestdb -hmysql
  {{ end }}
EOH
}
