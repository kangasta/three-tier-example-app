variable "namespace" {
  type    = string
  default = "three-tier-example-app"
}

variable "service_type" {
  type    = string
  default = "NodePort"
}

variable "pvc_storage_class" {
  type    = string
  default = ""
}

variable "app_version" {
  type    = string
  default = "latest"
}

provider "kubernetes" {
  ignore_annotations = [
    "^service\\.beta\\.kubernetes\\.io\\/.*load.*balancer.*"
  ]
}

data "kubernetes_nodes" "this" {}

locals {
  addresses   = data.kubernetes_nodes.this.nodes[0].status[0].addresses
  external_ip = local.addresses[index(local.addresses.*.type, "ExternalIP")].address
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "api" {
  metadata {
    name      = "api"
    namespace = var.namespace
    labels = {
      app = "api"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "api"
      }
    }

    template {
      metadata {
        labels = {
          app = "api"
        }
      }

      spec {
        container {
          image = "ghcr.io/kangasta/three-tier-example-app-api:${var.app_version}"
          name  = "api"

          env {
            name  = "DB_URL"
            value = "postgresql://user:pass@db:5432/feedback"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "api" {
  metadata {
    name      = "api"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "api"
    }

    port {
      port        = 80
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "ui" {
  metadata {
    name      = "ui"
    namespace = var.namespace
  }
  data = {
    config   = "const serverUrl = \"/api\";"
    resolver = "resolver kube-dns.kube-system.svc.cluster.local;"
  }
  depends_on = [kubernetes_service.api]
}

resource "kubernetes_deployment" "ui" {
  metadata {
    name      = "ui"
    namespace = var.namespace
    labels = {
      app = "ui"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "ui"
      }
    }

    template {
      metadata {
        labels = {
          app = "ui"
        }
      }

      spec {
        container {
          image = "ghcr.io/kangasta/three-tier-example-app-ui:${var.app_version}"
          name  = "ui"

          env {
            name  = "PROXY_PASS"
            value = "http://api.${var.namespace}.svc.cluster.local"
          }

          volume_mount {
            name       = "ui"
            mount_path = "/usr/share/nginx/html/config.js"
            sub_path   = "config"
          }

          volume_mount {
            name       = "ui"
            mount_path = "/etc/nginx/conf.d/resolver.conf"
            sub_path   = "resolver"
          }
        }

        volume {
          name = "ui"
          config_map {
            name = "ui"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ui" {
  metadata {
    name      = "ui"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "ui"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = var.service_type
  }
}

resource "kubernetes_persistent_volume_claim" "db" {
  count = var.pvc_storage_class != "" ? 1 : 0

  metadata {
    name      = "db"
    namespace = var.namespace
  }

  spec {
    storage_class_name = "upcloud-block-storage-maxiops"
    access_modes       = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "db" {
  metadata {
    name      = "db"
    namespace = var.namespace
    labels = {
      app = "db"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "db"
      }
    }

    template {
      metadata {
        labels = {
          app = "db"
        }
      }

      spec {
        container {
          image = "postgres:14"
          name  = "db"

          env {
            name  = "POSTGRES_USER"
            value = "user"
          }

          env {
            name  = "POSTGRES_PASSWORD"
            value = "pass"
          }

          env {
            name  = "POSTGRES_DB"
            value = "feedback"
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          dynamic "volume_mount" {
            for_each = kubernetes_persistent_volume_claim.db
            content {
              name       = "db-datadir"
              mount_path = "/var/lib/postgresql/data"
            }
          }
        }

        dynamic "volume" {
          for_each = kubernetes_persistent_volume_claim.db
          content {
            name = "db-datadir"
            persistent_volume_claim {
              claim_name = volume.value.metadata[0].name
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "db" {
  metadata {
    name      = "db"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "db"
    }

    port {
      port        = 5432
      target_port = 5432
    }
  }
}

output "ui_url" {
  value = var.service_type == "LoadBalancer" ? kubernetes_service.ui.status[0].load_balancer[0].ingress[0].hostname : "http://${local.external_ip}:${kubernetes_service.ui.spec[0].port[0].node_port}"
}
