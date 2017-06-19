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

variable "configuration" {
  description = "The configuration that should be applied"
}

variable "cluster_ca_certificate" {}

data "template_file" "template_deployment_yaml" {
  template = "${file("k8s/deployment.yaml.tpl")}"

  vars {
    OVPN_CN         = "${var.endpoint_server}"
    OVPN_SERVER_URL = "${var.endpoint_server}"
  }
}

resource "null_resource" "kubernetes_resource" {
  provisioner "local-exec" {
    command = "kubectl delete --context=${var.cluster_server} -f - <<EOF\n${var.configuration}\nEOF"
    when    = "destroy"
  }

  triggers {
    configuration = "${data.template_file.template_deployment_yaml.rendered}"
  }

  provisioner "local-exec" {
    command = "touch ${path.module}/kubeconfig"
  }

  provisioner "local-exec" {
    command = "echo '${var.cluster_ca_certificate}' > ${path.module}/ca.pem"
  }

  provisioner "local-exec" {
    command = "kubectl apply --kubeconfig=${path.module}/kubeconfig --server=${var.cluster_server} --certificate-authority=${path.module}/ca.pem --username=${var.username} --password=${var.password} -f - <<EOF\n${data.template_file.template_deployment_yaml.rendered}\nEOF"
  }
}
