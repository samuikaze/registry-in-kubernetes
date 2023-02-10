resource "kubernetes_namespace_v1" "self-hosted-registry" {
  metadata {
    name = var.namespace_name
  }
}

resource "kubernetes_secret_v1" "cert-secrets" {
  metadata {
    name = "cert-secrets"
    namespace = var.namespace_name
  }
  type = "tls"
  data = {
    cert = "/registry/certs/tls.crt"
    key = "/registry/certs/tls.key"
  }
}

resource "kubernetes_secret_v1" "auth-secrets" {
  metadata {
    name = "auth-secrets"
    namespace = var.namespace_name
  }

  type = "generic"
  data = {
    htpasswd = file("/var/lib/registry/auth/htpasswd")
  }
}

resource "kubernetes_persistent_volume_v1" "persistent-volume" {
  metadata {
    name = "podman-registry-pv"
  }

  spec {
    capacity = {
      storage = var.persistent_volume_size
    }
    access_modes = [ "ReadWriteOnce" ]
    persistent_volume_source {
      host_path {
        path = var.repositories_volume_path
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "persistent-volume-claim" {
  metadata {
    name = "podman-registry-pvc"
    namespace = var.namespace_name
  }

  spec {
    access_modes = [ "ReadWriteOnce" ]
    resources {
      requests = {
        storage = var.persistent_volume_size
      }
    }
  }
}

resource "kubernetes_deployment_v1" "podman-registry-deployment" {
  metadata {
    name = var.app_name
    namespace = var.namespace_name

    labels = {
      app_name = var.app_name
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app_name = var.app_name
      }
    }
    template {
      metadata {
        labels = {
          app_name = var.app_name
        }
      }

      spec {
        container {
          name = var.app_name
          image = var.image_name
          port {
            protocol = "TCP"
            container_port = var.host_port
            host_port = var.host_port
          }

          env {
            name = "REGISTRY_HTTP_TLS_CERTIFICATES"
            value_from {
              secret_key_ref {
                name = "cert-secrets"
                key = "cert"
              }
            }
          }

          env {
            name = "REGISTRY_HTTP_TLS_KEY"
            value_from {
              secret_key_ref {
                name = "cert-secrets"
                key = "key"
              }
            }
          }

          env {
            name = "REGISTRY_AUTH_HTPASSWD_REALM"
            value = "basic_realm"
          }

          env {
            name = "REGISTRY_AUTH_HTPASSWD_PATH"
            value = format("%s/htpasswd", var.authorization_volume_path)
          }

          volume_mount {
            name = "repository-volume"
            mount_path = var.repositories_volume_path
            # sub_path = "registry"
          }

          volume_mount {
            name = "certificates-volume"
            mount_path = var.certificates_volume_path
            read_only = true
          }

          volume_mount {
            name = "authorization-volume"
            mount_path = var.authorization_volume_path
          }
        }

        volume {
          name = "repository-volume"
          persistent_volume_claim {
            claim_name = "podman-registry-pvc"
          }
        }

        volume {
          name = "certificates-volume"
          secret {
            secret_name = "cert-secrets"
          }
        }

        volume {
          name = "authorization-volume"
          secret {
            secret_name = "auth-secrets"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "podman-registry-service" {
  metadata {
    name = var.app_name
    namespace = var.namespace_name
  }

  spec {
    type = "ClusterIP"
    selector = {
      app_name = var.app_name
    }

    port {
      protocol = "TCP"
      port = var.host_port
      target_port = var.host_port
    }
  }
}
