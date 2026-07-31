terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # Remote state in Azure Storage.
  # Values are supplied at `terraform init` time via -backend-config
  # (see the GitHub Actions workflow), so no secrets live in this file.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  # Tells the provider to use the OIDC token that azure/login already
  # placed in the environment instead of a client secret.
  use_oidc = true
}
