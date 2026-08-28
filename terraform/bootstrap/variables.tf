variable "region" {
  description = "NCP region"
  type        = string
  default     = "KR"
}

variable "zone" {
  description = "NCP zone (전 리소스 통일)"
  type        = string
  default     = "KR-2"
}

variable "name_prefix" {
  description = "리소스 이름 접두"
  type        = string
  default     = "nks-practice"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnets" {
  description = "서브넷 정의 (spec.md §4.1)"
  type = map(object({
    cidr        = string
    subnet_type = string # PUBLIC | PRIVATE
    usage_type  = string # GEN | LOADB
  }))
  default = {
    node = {
      cidr        = "10.0.1.0/24"
      subnet_type = "PRIVATE"
      usage_type  = "GEN"
    }
    lb_private = {
      cidr        = "10.0.2.0/24"
      subnet_type = "PRIVATE"
      usage_type  = "LOADB"
    }
    public = {
      cidr        = "10.0.0.0/24"
      subnet_type = "PUBLIC"
      usage_type  = "GEN"
    }
    lb_public = {
      cidr        = "10.0.3.0/24"
      subnet_type = "PUBLIC"
      usage_type  = "LOADB"
    }
  }
}
