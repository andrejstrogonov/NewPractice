locals {
  app_labels = {
    "app.kubernetes.io/part-of"    = "vpn-proxy"
    "app.kubernetes.io/managed-by" = "terraform"
  }

  grpc_app_dir = "${path.module}/assets/grpc-integrity"

  nginx_conf = templatefile("${path.module}/templates/nginx.conf.tftpl", {
    domain_name       = var.domain_name
    keycloak_hostname = var.keycloak_hostname
    keycloak_realm    = var.keycloak_realm
    keycloak_client   = var.keycloak_client_id
  })
}

resource "kubernetes_namespace_v1" "vpn" {
  metadata {
    name = var.namespace
    labels = local.app_labels
  }
}

resource "helm_release" "postgresql" {
  name       = "postgresql"
  namespace  = kubernetes_namespace_v1.vpn.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"

  values = [
    yamlencode({
      auth = {
        postgresPassword = var.postgres_password
        username         = "keycloak"
        password         = var.postgres_password
        database         = "keycloak"
      }
      primary = {
        persistence = {
          enabled      = true
          size         = "8Gi"
          storageClass = var.storage_class_name
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.vpn]
}

resource "helm_release" "keycloak" {
  name       = "keycloak"
  namespace  = kubernetes_namespace_v1.vpn.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "keycloak"

  values = [
    yamlencode({
      auth = {
        adminUser     = var.keycloak_admin_user
        adminPassword = var.keycloak_admin_password
      }
      production = true
      proxy      = "edge"
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled  = false
        hostname = var.keycloak_hostname
      }
      postgresql = {
        enabled  = false
        auth = {
          username = "keycloak"
          password = var.postgres_password
          database = "keycloak"
        }
        primary = {
          service = {
            ports = {
              postgresql = 5432
            }
          }
        }
      }
      externalDatabase = {
        host     = "postgresql"
        port     = 5432
        user     = "keycloak"
        password = var.postgres_password
        database = "keycloak"
      }
    })
  ]

  depends_on = [helm_release.postgresql]
}

resource "kubernetes_persistent_volume_claim_v1" "openvpn" {
  metadata {
    name      = "openvpn-pvc"
    namespace = kubernetes_namespace_v1.vpn.metadata[0].name
    labels    = local.app_labels
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.openvpn_storage_size
      }
    }
    storage_class_name = var.storage_class_name
  }
}

resource "kubernetes_config_map_v1" "grpc_integrity" {
  metadata {
    name      = "integrity-grpc-src"
    namespace = kubernetes_namespace_v1.vpn.metadata[0].name
    labels    = local.app_labels
  }

  data = {
    "package.json"    = file("${local.grpc_app_dir}/package.json")
    "server.js"       = file("${local.grpc_app_dir}/server.js")
    "integrity.proto" = file("${local.grpc_app_dir}/integrity.proto")
    "health.proto"    = file("${local.grpc_app_dir}/health.proto")
  }
}

resource "kubernetes_secret_v1" "integrity_env" {
  metadata {
    name      = "integrity-grpc-env"
    namespace = kubernetes_namespace_v1.vpn.metadata[0].name
    labels    = local.app_labels
  }

  string_data = {
    NEURAL_API_KEY = var.integrity_api_key
  }
}

resource "kubernetes_deployment_v1" "integrity_grpc" {
  metadata {
    name      = "integrity-grpc"
    namespace = kubernetes_namespace_v1.vpn.metadata[0].name
    labels = merge(local.app_labels, {
      app = "integrity-grpc"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "integrity-grpc"
      }
    }

    template {
      metadata {
        labels = merge(local.app_labels, {
          app = "integrity-grpc"
        })
      }

      spec {
        container {
          name              = "grpc-server"
          image             = "node:20-alpine"
          image_pull_policy = "IfNotPresent"
          working_dir       = "/app"
          command           = ["/bin/sh", "-c"]
          args              = ["cp /bootstrap/* /app/ && npm install --omit=dev && node server.js"]

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.integrity_env.metadata[0].name
            }
          }

          port {
            container_port = 50051
            name           = "grpc"
          }

          volume_mount {
            name       = "app-src"
            mount_path = "/app"
          }

          volume_mount {
            name       = "bootstrap-src"
            mount_path = "/bootstrap"
            read_only  = true
          }
        }

        volume {
          name = "app-src"
          empty_dir {}
        }

        volume {
          name = "bootstrap-src"
          config_map {
            name = kubernetes_config_map_v1.grpc_integrity.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "integrity_grpc" {
  metadata {
    name      = "integrity-grpc-svc"
    namespace = kubernetes_namespace_v1.vpn.metadata[0].name
    labels    = local.app_labels
  }

  spec {
    selector = {
      app = "integrity-grpc"
    }

    port {
      name        = "grpc"
      port        = 50051
      target_port = 50051
    }
  }
}

resource "kubernetes_config_map_v1" "nginx" {
  metadata {
    name      = "vpn-proxy-nginx"
    namespace = kubernetes_namespace_v1.vpn.metadata[0].name
    labels    = local.app_labels
  }

  data = {
    "nginx.conf" = local.nginx_conf
  }
}

resource "kubernetes_deployment_v1" "vpn_proxy" {
  metadata {
    name      = "vpn-proxy"
    namespace = kubernetes_namespace_v1.vpn.metadata[0].name
    labels = merge(local.app_labels, {
      app = "vpn-proxy"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "vpn-proxy"
      }
    }

    template {
      metadata {
        labels = merge(local.app_labels, {
          app = "vpn-proxy"
        })
      }

      spec {
        container {
          name              = "nginx"
          image             = "nginx:1.27-alpine"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 80
            name           = "http"
          }

          port {
            container_port = 443
            name           = "https"
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "nginx.conf"
          }

          volume_mount {
            name       = "tls"
            mount_path = "/etc/nginx/tls"
            read_only  = true
          }
        }

        volume {
          name = "nginx-config"
          config_map {
            name = kubernetes_config_map_v1.nginx.metadata[0].name
          }
        }

        volume {
          name = "tls"
          secret {
            secret_name = var.tls_secret_name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "vpn_proxy" {
  metadata {
    name      = "vpn-proxy-svc"
    namespace = kubernetes_namespace_v1.vpn.metadata[0].name
    labels    = local.app_labels
  }

  spec {
    selector = {
      app = "vpn-proxy"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    port {
      name        = "https"
      port        = 443
      target_port = 443
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_deployment_v1" "openvpn" {
  metadata {
    name      = "openvpn-server"
    namespace = kubernetes_namespace_v1.vpn.metadata[0].name
    labels = merge(local.app_labels, {
      app = "openvpn-server"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "openvpn-server"
      }
    }

    template {
      metadata {
        labels = merge(local.app_labels, {
          app = "openvpn-server"
        })
      }

      spec {
        container {
          name              = "openvpn"
          image             = "kylemanna/openvpn:2.5"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 1194
            protocol       = "UDP"
          }

          security_context {
            capabilities {
              add = ["NET_ADMIN"]
            }
          }

          volume_mount {
            name       = "openvpn-data"
            mount_path = "/etc/openvpn"
          }
        }

        volume {
          name = "openvpn-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.openvpn.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "openvpn" {
  metadata {
    name      = "openvpn-svc"
    namespace = kubernetes_namespace_v1.vpn.metadata[0].name
    labels    = local.app_labels
  }

  spec {
    selector = {
      app = "openvpn-server"
    }

    port {
      name        = "openvpn-udp"
      port        = 1194
      target_port = 1194
      protocol    = "UDP"
    }

    type = "LoadBalancer"
  }
}
