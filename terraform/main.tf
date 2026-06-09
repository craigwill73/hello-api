locals {
  tags = {
    project     = "hello-api"
    environment = "trial"
    purpose     = "hello-api"
  }
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.aks_name
  sku_tier            = "Free"
  tags                = local.tags

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.node_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
    load_balancer_sku = "standard"
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

resource "azurerm_public_ip" "hello" {
  name                = "pip-hello-api"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_kubernetes_cluster.main.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags

  depends_on = [azurerm_kubernetes_cluster.main]
}

resource "kubernetes_deployment" "hello" {
  wait_for_rollout = false

  metadata {
    name = "hello-api"
    labels = {
      app = "hello-api"
    }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        app = "hello-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-api"
        }
      }

      spec {
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "kubernetes.io/hostname"
          when_unsatisfiable = "DoNotSchedule"

          label_selector {
            match_labels = {
              app = "hello-api"
            }
          }
        }

        container {
          name  = "hello-api"
          image = "${azurerm_container_registry.main.login_server}/${var.image_name}:${var.image_tag}"

          image_pull_policy = "Always"

          port {
            container_port = 8000
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.aks_acr_pull,
  ]
}

resource "kubernetes_service" "hello" {
  metadata {
    name = "hello-api"
    annotations = {
      "service.beta.kubernetes.io/azure-pip-name"                    = azurerm_public_ip.hello.name
      "service.beta.kubernetes.io/azure-load-balancer-resource-group" = azurerm_kubernetes_cluster.main.node_resource_group
    }
  }

  spec {
    type             = "LoadBalancer"
    load_balancer_ip = azurerm_public_ip.hello.ip_address

    selector = {
      app = "hello-api"
    }

    port {
      port        = 80
      target_port = 8000
    }
  }

  depends_on = [kubernetes_deployment.hello]
}

resource "kubernetes_pod_disruption_budget_v1" "hello" {
  metadata {
    name = "hello-api"
  }

  spec {
    min_available = 1

    selector {
      match_labels = {
        app = "hello-api"
      }
    }
  }

  depends_on = [kubernetes_deployment.hello]
}
