output "gcp.openvpn_cluster.endpoint" {
  value = "${google_container_cluster.openvpn_cluster.endpoint}"
}

output "gcp.openvpn_ingress_endpoint" {
  value = "${google_compute_address.openvpn_ingress.address}"
}

output "gcp.openvpn_cluster.instance_group_urls" {
  value = "${google_container_cluster.openvpn_cluster.instance_group_urls}"
}
