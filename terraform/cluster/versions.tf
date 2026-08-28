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

# bootstrap 스택 output 참조 (로컬 state)
data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = "${path.module}/../bootstrap/terraform.tfstate"
  }
}
