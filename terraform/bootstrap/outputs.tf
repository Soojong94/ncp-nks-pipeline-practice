output "vpc_no" {
  value = ncloud_vpc.this.id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "default_network_acl_no" {
  value = ncloud_vpc.this.default_network_acl_no
}

output "default_private_route_table_no" {
  description = "cluster 스택에서 NAT Gateway 라우트 추가 대상"
  value       = ncloud_vpc.this.default_private_route_table_no
}

output "default_public_route_table_no" {
  value = ncloud_vpc.this.default_public_route_table_no
}

output "subnet_ids" {
  description = "서브넷 역할 -> subnet_no"
  value       = { for k, s in ncloud_subnet.this : k => s.id }
}

output "login_key_name" {
  value = ncloud_login_key.this.key_name
}

output "acg_node_no" {
  value = ncloud_access_control_group.node.id
}

output "acg_lb_no" {
  value = ncloud_access_control_group.lb.id
}
