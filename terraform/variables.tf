variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "resource_group_name" {
  type    = string
  default = "rg-hello-api"
}

variable "acr_name" {
  type        = string
  description = "Globally unique ACR name (alphanumeric only)"
}

variable "aks_name" {
  type    = string
  default = "aks-hello-api"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_B2s_v2"
}

variable "image_name" {
  type    = string
  default = "hello-api"
}

variable "image_tag" {
  type    = string
  default = "latest"
}
