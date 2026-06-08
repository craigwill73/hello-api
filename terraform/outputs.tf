output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "hello_url" {
  value = "http://${azurerm_public_ip.hello.ip_address}/hello"
}

output "public_ip" {
  value = azurerm_public_ip.hello.ip_address
}
