variable endpoint_server {}

# Create the pki
resource null_resource "provision_pki" {
  provisioner "local-exec" {
    command = "${path.module}/create_pki.sh ${var.endpoint_server}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "rm -R pki"
  }
}

# bash shell microservice returns pki information
data "external" "pki" {
  depends_on = ["null_resource.provision_pki"]
  program = ["bash", "${path.module}/pki_service.sh"]

  query = {
    endpoint_server = "${var.endpoint_server}"
  }
}

# outputs

output "ca_crt" {
  value = "${data.external.pki.result.ca_crt}"
}

output "certificate_crt" {
  value = "${data.external.pki.result.cert_crt}"
}

output "private_key" {
  value = "${data.external.pki.result.private_key}"
}

output "dh_pem" {
  value = "${data.external.pki.result.dh_pem}"
}

output "ta_key" {
  value = "${data.external.pki.result.ta_key}"
}
