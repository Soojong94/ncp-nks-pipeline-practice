terraform {
  required_version = ">= 1.6"

  required_providers {
    ncloud = {
      source  = "NaverCloudPlatform/ncloud"
      version = "~> 3.3"
    }
  }

  # 1차는 로컬 state. spec.md §12 오픈이슈 — M1 이후 OBS 백엔드 판단.
  # backend "s3" { ... }  # NCP Object Storage (S3 호환)
}

provider "ncloud" {
  # 자격증명은 환경변수: NCLOUD_ACCESS_KEY / NCLOUD_SECRET_KEY / NCLOUD_REGION
  region      = var.region
  site        = "public"
  support_vpc = true
}
