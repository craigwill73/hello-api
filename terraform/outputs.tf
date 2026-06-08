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
  value = var.enable_frontdoor_waf ? "http://${azurerm_cdn_frontdoor_endpoint.hello[0].host_name}/hello" : "http://${azurerm_public_ip.hello.ip_address}/hello"
}

output "hello_url_direct" {
  description = "Direct LoadBalancer IP (bypasses WAF)"
  value       = "http://${azurerm_public_ip.hello.ip_address}/hello"
}

output "frontdoor_host" {
  value = var.enable_frontdoor_waf ? azurerm_cdn_frontdoor_endpoint.hello[0].host_name : null
}

output "public_ip" {
  value = azurerm_public_ip.hello.ip_address
}
