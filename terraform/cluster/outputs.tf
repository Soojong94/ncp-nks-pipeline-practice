output "cluster_uuid" {
  value = ncloud_nks_cluster.this.uuid
}

output "cluster_name" {
  value = ncloud_nks_cluster.this.name
}

output "cluster_endpoint" {
  value = ncloud_nks_cluster.this.endpoint
}

output "k8s_version" {
  value = local.k8s_version
}

output "nat_public_ip" {
  value = ncloud_nat_gateway.this.public_ip
}

output "lb_public_subnet_no" {
  value = local.lb_pub_sn
}

output "lb_private_subnet_no" {
  value = local.lb_priv_sn
}

output "kubeconfig_cmd" {
  description = "kubeconfig 생성 명령"
  value       = "ncp-iam-authenticator create-kubeconfig --region ${var.region} --clusterUuid ${ncloud_nks_cluster.this.uuid} > kubeconfig"
}
