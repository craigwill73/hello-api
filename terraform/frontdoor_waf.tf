variable "enable_frontdoor_waf" {
  type        = bool
  default     = true
  description = "Place Azure Front Door WAF in front of the public LoadBalancer IP"
}

variable "waf_rate_limit_threshold" {
  type        = number
  default     = 100
  description = "Max requests per client IP per minute before WAF blocks"
}

resource "azurerm_cdn_frontdoor_profile" "hello" {
  count               = var.enable_frontdoor_waf ? 1 : 0
  name                = "fd-hello-api"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = local.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "hello" {
  count                    = var.enable_frontdoor_waf ? 1 : 0
  name                     = "hello-api-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.hello[0].id
  tags                     = local.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "hello" {
  count                    = var.enable_frontdoor_waf ? 1 : 0
  name                     = "hello-api-origins"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.hello[0].id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 2
  }

  health_probe {
    path                = "/hello"
    protocol            = "Http"
    interval_in_seconds = 30
  }
}

resource "azurerm_cdn_frontdoor_origin" "hello" {
  count                          = var.enable_frontdoor_waf ? 1 : 0
  name                           = "hello-api-lb"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.hello[0].id
  enabled                        = true
  host_name                      = azurerm_public_ip.hello.ip_address
  origin_host_header             = azurerm_public_ip.hello.ip_address
  http_port                      = 80
  https_port                     = 443
  certificate_name_check_enabled   = false
  priority                       = 1
  weight                         = 1000
}

resource "azurerm_cdn_frontdoor_route" "hello" {
  count                          = var.enable_frontdoor_waf ? 1 : 0
  name                           = "hello-api-route"
  cdn_frontdoor_endpoint_id      = azurerm_cdn_frontdoor_endpoint.hello[0].id
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.hello[0].id
  cdn_frontdoor_origin_ids       = [azurerm_cdn_frontdoor_origin.hello[0].id]
  enabled                        = true
  forwarding_protocol            = "HttpOnly"
  https_redirect_enabled         = false
  patterns_to_match              = ["/*"]
  supported_protocols            = ["Http", "Https"]

  link_to_default_domain = true
}

resource "azurerm_cdn_frontdoor_firewall_policy" "hello" {
  count               = var.enable_frontdoor_waf ? 1 : 0
  name                = "wafhelloapi"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard_AzureFrontDoor"
  enabled             = true
  mode                = "Prevention"

  # Managed OWASP/bot rulesets require Premium_AzureFrontDoor.
  # Standard SKU supports custom rate limiting below.

  custom_rule {
    name                           = "RateLimitPerIp"
    enabled                        = true
    priority                       = 1
    type                           = "RateLimitRule"
    action                         = "Block"
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = var.waf_rate_limit_threshold

    match_condition {
      match_variable = "RemoteAddr"
      operator       = "IPMatch"
      match_values   = ["0.0.0.0/0"]
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "hello" {
  count                    = var.enable_frontdoor_waf ? 1 : 0
  name                     = "hello-api-waf-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.hello[0].id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.hello[0].id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.hello[0].id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
