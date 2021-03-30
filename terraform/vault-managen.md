# Vault managen mit _Infrastructure as Code_ 

## Problem

Vault muss konfiguriert und betrieben werden. Idealerweise soll dies genau so automatisiert und nachvollziehbar ausgeführt werden, wie bei normalen Applikationen.

## Mögliche Lösung

Terraform bietet Module an, um einen Vault zu managen

### Problem mit Terraform

Mit Terraform können Systeme deklarativ beschrieben werden. Um Idempotenz zu garantieren und keine anderweitig erstellten Ressourcen zu beeinflussen, speichert Terraform den Zustand des aktuellen Systems nach jeder Ausführung als *State* ab. In diesem State sind auch potentiell sensitive Daten als Klartext enthalten. Terraform braucht den State, um ausführbar zu sein

Das Hauptproblem einer Automatisierung mit Terraform ist die sichere Persistenz des States.

<div class="pagebreak"/>

### Mögliche Lösung

1. State wird in Kubernetes-Secrets gespeichert, Zugriff ist streng eingeschränkt

2. der State beinhaltet keine oder möglichst wenig Secrets

   - die Secrets (zum Beispiel Root-Passwörter von Datenbanken) werden manuell an definierte Stellen in den Vault geschrieben (siehe `username` und `password`)

     ```
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
     ```

     Entwickler bereiten die Terraform-Skripte vor, commiten die Änderungen und erstellen einen Pull-Request. Voraussetzung für den Pull-Request ist, dass "jemand" vom Infrastrukturteam die entsprechenden Secrets an die richtige Stelle geschrieben hat (hier: `/admin/secrets/project1-db`). Entwickler brauchen keinen Zugriff auf den Pfad `/admin/secrets/project1-db`.<div class="pagebreak"/>

   - die Secrets werden in den Terraform-Skripten referenziert, Root-Passwörter werden direkt nach dem Anlegen [automatisch rotiert](https://learn.hashicorp.com/tutorials/vault/database-root-rotation) -- damit hat selbst der Zugriff auf `/admin/secrets/project1-db` keinen Nutzen

     ```
     resource "vault_generic_endpoint" "rotate_initial_project1_db_pw" {
       depends_on           = [vault_database_secret_backend_connection.project1_db]
       path                 = "${vault_database_secret_backend_connection.project1_db.backend}/rotate-root/${vault_database_secret_backend_connection.project1_db.name}"
       disable_read   = true
       disable_delete = true
     
       data_json = "{}"
     }
     
     ```

3. nach einem initialen Terraform-Lauf, der Vault für die Nutzung von Kubernetes aufsetzt und evtl. einige Kubernetes-Ressourcen erstellt (evtl. möchte man das Erstellen von Kubernetes-Ressourcen nicht via Terraform ausführen), wird Terraform ausschließlich automatisiert in Kubernetes selbst als Kubernetes-Job ausgeführt. Terraform authentifiziert sich gegen Vault mit Kubernetes-Auth unter Nutzung des Vault-Injectors.

   - Initiales Setup: terraform wird einmalig mit weitreichenden Rechte lokal ausgeführt

   
   - automatisiertes Terraform in Kuberenets / OpenShift
   
     ![terraform deploy in kubernetes](k8s-terraform-run.svg)



### Aufsplittung: IaC vs. Secrets

Um eine Aufteilung von Secrets und Konfiguration der Policies, Rollen und verschiedenen Secrets-Backends zu erreichen, werden die Secrets (z. B. Root-Passwörter für Datenbanken, nicht änderbare API-Keys, etc.) manuell in Vault geschrieben. Die restlichen Konfigurationen werden in ein Repo per Pull Request geschrieben.

Bei rotierbaren Root-Passwörtern kann die oben beschriebene Strategie genutzt werden (Admins schreiben initiales Passwort in ein bestimmtes Secret, Terraform liest es von dort und ändert es sofort) -- rollierte Passwörter werden nicht in den State gespeichert.

Bei statischen Secrets wird die Structur zunächst mit Terraform erstellt, anschließend werden die Werte manuell gesetzt. Entsprechende Properties werden mit bei statischen Secrets mit:

```
disable_read = true
```

markiert oder bei anderen resourcen mit:

```
  lifecycle {
    ignore_changes = [
      <property>,
    ]
  }

```

ignoriert. So kann erreicht werden, dass diese Secrets nicht im State-File landet.

### Todos

- Liste der Arten von Secrets, die gespeichert werden müssen erstellen
- evtl. eine Art Tagging von Resourcen, die Terraform ignoriert und die deshalb händisch gesetzt werden müssen
- entscheiden, ob Kubernetes-Operationen teilweise auch mit Terraform durchgeführt werden sollen oder nicht
- PoC demonstrieren, PoC bei Verbund implementieren