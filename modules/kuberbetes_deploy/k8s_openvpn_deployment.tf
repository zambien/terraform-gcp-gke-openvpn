# A module that can create Kubernetes resources from YAML file descriptions.

variable "username" {
  description = "The Kubernetes username to use"
}

variable "password" {
  description = "The Kubernetes password to use"
}

variable "cluster_server" {
  description = "The address and port of the Kubernetes API server"
}

variable "endpoint_server" {
  description = "The address and port of the deployment endpoint"
}

variable "secret_uid" {
  description = "We don't actually need this... we pretend we do so that this module waits for secrets to be created."
}

variable "cluster_ca_certificate" {}

data "template_file" "template_deployment_yaml" {
  template = "${file("${path.module}/deployment.yaml.tpl")}"

  vars {
    OVPN_CN         = "${var.endpoint_server}"
    OVPN_SERVER_URL = "tcp://${var.endpoint_server}:1194"
  }
}

resource "null_resource" "kubernetes_deployments" {

  provisioner "local-exec" {
    command = "kubectl delete service terraform-gke-openvpn"
    when    = "destroy"
  }

  provisioner "local-exec" {
    command = "sleep 10 && kubectl delete -f - <<EOF\n${data.template_file.template_deployment_yaml.rendered}\nEOF"
    when    = "destroy"
  }

  /*
  provisioner "local-exec" {
    command = "kubectl delete -f - <<EOF\n${file("${path.module}/static-ip-ingress.yaml")}\nEOF"
    when    = "destroy"
  }*/

  triggers {
    configuration = "${data.template_file.template_deployment_yaml.rendered}"
  }

  provisioner "local-exec" {
    command = "echo ${var.secret_uid} && kubectl create -f - <<EOF\n${data.template_file.template_deployment_yaml.rendered}\nEOF"
  }

  provisioner "local-exec" {
      command = "sleep 10 && kubectl expose deployment terraform-gke-openvpn --name=terraform-gke-openvpn --type=LoadBalancer --protocol=TCP --port=80 --target-port=1194"
  }

  /*
  provisioner "local-exec" {
    command = "echo ${var.secret_uid} && kubectl create -f - <<EOF\n${file("${path.module}/static-ip-ingress.yaml")}\nEOF"
  }*/
}
