variable "region" {
  type    = string
  default = "KR"
}

variable "name_prefix" {
  type    = string
  default = "nks-practice"
}

variable "ncr_name" {
  description = "M1 에서 콘솔 생성한 Container Registry 이름"
  type        = string
  default     = "nkspracticecr"
}

variable "source_branch" {
  type    = string
  default = "master"
}

# SourceBuild 이미지 빌드용 인증 (env_var 로 주입). tfvars(gitignore) 또는 TF_VAR_ 로.
variable "ncp_access_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ncp_secret_key" {
  type      = string
  default   = ""
  sensitive = true
}
