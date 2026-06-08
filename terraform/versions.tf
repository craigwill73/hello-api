terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-hello-api-tfstate"
    storage_account_name = "sthelloapicw73"
    container_name       = "tfstate"
    key                  = "hello-api.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}
