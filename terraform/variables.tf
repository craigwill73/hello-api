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

variable "node_count" {
  type        = number
  default     = 2
  description = "Number of nodes in the default AKS node pool"
}

variable "replica_count" {
  type        = number
  default     = 2
  description = "Number of hello-api pods (spread across nodes when possible)"
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
