variable "region" {
  type    = string
  default = "KR"
}

variable "zone" {
  type    = string
  default = "KR-2"
}

variable "name_prefix" {
  type    = string
  default = "nks-practice"
}

variable "hypervisor_code" {
  description = "s2-g2-h50 = g2 세대 → KVM"
  type        = string
  default     = "KVM"
}

variable "k8s_version" {
  description = "null 이면 data.ncloud_nks_versions 의 최신 버전 사용"
  type        = string
  default     = null
}

variable "cluster_type" {
  description = "컨트롤플레인 크기. apply 전 콘솔/문서로 유효값 확인. G002 = 최대 10노드급"
  type        = string
  default     = "SVR.VNKS.STAND.C002.M008.NET.SSD.B050.G002"
}

variable "node_spec_code" {
  description = "노드 서버 스펙 (확정: s2-g2-h50 = 2vCPU/8GB/50GB)"
  type        = string
  default     = "s2-g2-h50"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "node_autoscale" {
  description = "M7 노드 오토스케일 실습 시 true"
  type = object({
    enabled = bool
    min     = number
    max     = number
  })
  default = {
    enabled = false
    min     = 2
    max     = 2
  }
}

variable "public_network" {
  description = "true = API 서버 공인 엔드포인트 (실습 편의). false = 사설만"
  type        = bool
  default     = true
}
