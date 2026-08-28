# =============================================================
# cluster 스택 — 세션별 apply / destroy (spec.md §4.2)
# NAT Gateway + route / NKS 클러스터 / 노드풀
# =============================================================

locals {
  bs           = data.terraform_remote_state.bootstrap.outputs
  node_subnet  = local.bs.subnet_ids["node"]
  public_sn    = local.bs.subnet_ids["public"]
  lb_priv_sn   = local.bs.subnet_ids["lb_private"]
  lb_pub_sn    = local.bs.subnet_ids["lb_public"]
  vpc_no       = local.bs.vpc_no
  priv_rt      = local.bs.default_private_route_table_no
  login_key    = local.bs.login_key_name
  k8s_version  = coalesce(var.k8s_version, try(data.ncloud_nks_versions.this.versions[0].value, null))
  server_image = try(data.ncloud_nks_server_images.this.images[0].value, null)
}

data "ncloud_nks_versions" "this" {
  hypervisor_code = var.hypervisor_code
}

data "ncloud_nks_server_images" "this" {
  hypervisor_code = var.hypervisor_code
}

# ---------- C1. NAT Gateway ----------
resource "ncloud_nat_gateway" "this" {
  name      = "${var.name_prefix}-natgw"
  vpc_no    = local.vpc_no
  subnet_no = local.public_sn
  zone      = var.zone
}

# ---------- C2. private route -> NAT ----------
resource "ncloud_route" "private_to_nat" {
  route_table_no         = local.priv_rt
  destination_cidr_block = "0.0.0.0/0"
  target_type            = "NATGW"
  target_name            = ncloud_nat_gateway.this.name
  target_no              = ncloud_nat_gateway.this.nat_gateway_no
}

# ---------- C3. NKS 클러스터 ----------
resource "ncloud_nks_cluster" "this" {
  name                 = "${var.name_prefix}-nks"
  cluster_type         = var.cluster_type
  hypervisor_code      = var.hypervisor_code
  k8s_version          = local.k8s_version
  login_key_name       = local.login_key
  zone                 = var.zone
  vpc_no               = local.vpc_no
  subnet_no_list       = [local.node_subnet]
  lb_private_subnet_no = local.lb_priv_sn
  lb_public_subnet_no  = local.lb_pub_sn
  public_network       = var.public_network
  kube_network_plugin  = "cilium"

  depends_on = [ncloud_route.private_to_nat]
}

# ---------- C4. 노드풀 ----------
resource "ncloud_nks_node_pool" "main" {
  cluster_uuid     = ncloud_nks_cluster.this.uuid
  node_pool_name   = "np-main"
  node_count       = var.node_autoscale.enabled ? null : var.node_count
  server_spec_code = var.node_spec_code
  software_code    = local.server_image
  subnet_no        = local.node_subnet
  k8s_version      = local.k8s_version

  autoscale {
    enabled = var.node_autoscale.enabled
    min     = var.node_autoscale.min
    max     = var.node_autoscale.max
  }
}
