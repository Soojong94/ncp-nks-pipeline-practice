# =============================================================
# bootstrap 스택 — 상시 유지 리소스 (spec.md §4.1)
# VPC / 서브넷 4종 / login key / ACG 2종
#
# 주의: NCR(Container Registry)은 ncloud Terraform provider에 리소스가
# 없음 → 콘솔에서 1회 생성. endpoint 는 이후 마일스톤에서 변수로 주입.
# (docs/PLAN.md, spec.md §4.1 B6 참고)
# =============================================================

# ---------- B1. VPC ----------
resource "ncloud_vpc" "this" {
  name            = "${var.name_prefix}-vpc"
  ipv4_cidr_block = var.vpc_cidr
}

# ---------- B2~B5. 서브넷 ----------
resource "ncloud_subnet" "this" {
  for_each = var.subnets

  name           = "${var.name_prefix}-sn-${replace(each.key, "_", "-")}"
  vpc_no         = ncloud_vpc.this.id
  subnet         = each.value.cidr
  zone           = var.zone
  network_acl_no = ncloud_vpc.this.default_network_acl_no
  subnet_type    = each.value.subnet_type
  usage_type     = each.value.usage_type
}

# ---------- B7. Login Key (노드 SSH 키페어) ----------
resource "ncloud_login_key" "this" {
  key_name = "${var.name_prefix}-key"
}

# ---------- B8. ACG — 노드 ----------
resource "ncloud_access_control_group" "node" {
  name        = "${var.name_prefix}-acg-node"
  vpc_no      = ncloud_vpc.this.id
  description = "NKS worker nodes"
}

resource "ncloud_access_control_group_rule" "node" {
  access_control_group_no = ncloud_access_control_group.node.id

  # VPC 내부 전체 통신 (노드<->컨트롤플레인, 노드간, LB->노드)
  inbound = [
    {
      description                    = "intra-vpc tcp"
      protocol                       = "TCP"
      ip_block                       = var.vpc_cidr
      port_range                     = "1-65535"
      source_access_control_group_no = null
    },
    {
      description                    = "intra-vpc udp"
      protocol                       = "UDP"
      ip_block                       = var.vpc_cidr
      port_range                     = "1-65535"
      source_access_control_group_no = null
    },
  ]

  # 아웃바운드 전체 (NAT 경유 이미지 pull 등)
  outbound = [
    {
      description                    = "all tcp out"
      protocol                       = "TCP"
      ip_block                       = "0.0.0.0/0"
      port_range                     = "1-65535"
      source_access_control_group_no = null
    },
    {
      description                    = "all udp out"
      protocol                       = "UDP"
      ip_block                       = "0.0.0.0/0"
      port_range                     = "1-65535"
      source_access_control_group_no = null
    },
  ]
}

# ---------- B9. ACG — LB ----------
resource "ncloud_access_control_group" "lb" {
  name        = "${var.name_prefix}-acg-lb"
  vpc_no      = ncloud_vpc.this.id
  description = "Load balancer (ingress)"
}

resource "ncloud_access_control_group_rule" "lb" {
  access_control_group_no = ncloud_access_control_group.lb.id

  inbound = [
    {
      description                    = "http"
      protocol                       = "TCP"
      ip_block                       = "0.0.0.0/0"
      port_range                     = "80"
      source_access_control_group_no = null
    },
    {
      description                    = "https"
      protocol                       = "TCP"
      ip_block                       = "0.0.0.0/0"
      port_range                     = "443"
      source_access_control_group_no = null
    },
  ]

  outbound = [
    {
      description                    = "to vpc"
      protocol                       = "TCP"
      ip_block                       = var.vpc_cidr
      port_range                     = "1-65535"
      source_access_control_group_no = null
    },
  ]
}
