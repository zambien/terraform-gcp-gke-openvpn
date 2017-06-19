output "gcc.openvpn_cluster.endpoint" {
        value = "http://${google_container_cluster.openvpn_cluster.endpoint}"
}

output "gcc.openvpn_cluster.instance_group_urls" {
  value = "${google_container_cluster.openvpn_cluster.instance_group_urls}"
}
