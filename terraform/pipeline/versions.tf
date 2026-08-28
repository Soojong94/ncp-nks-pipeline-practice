terraform {
  required_version = ">= 1.6"

  required_providers {
    ncloud = {
      source  = "NaverCloudPlatform/ncloud"
      version = "~> 3.3"
    }
  }
}

provider "ncloud" {
  region      = var.region
  site        = "public"
  support_vpc = true
}

data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config  = { path = "${path.module}/../bootstrap/terraform.tfstate" }
}

data "terraform_remote_state" "cluster" {
  backend = "local"
  config  = { path = "${path.module}/../cluster/terraform.tfstate" }
}
