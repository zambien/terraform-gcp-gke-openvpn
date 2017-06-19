variable "google_project" {
  default = "terraform-gcp-openvpn"
}

variable "prefix" {
  default = "openvpn"
}

variable "region" {
  default = "us-east1"
}

variable "cluster_master_username" {}
variable "cluster_master_password" {}

# Configure the Google Cloud provider
provider "google" {
  credentials = "${file("~/.gcp/${var.google_project}.json")}"
  project     = "${var.google_project}"
  region      = "${var.region}"
}

provider "kubernetes" {}

# Enable APIs for project so terraform can do it's thing
resource "google_project_services" "openvpn_project" {
  project = "${var.google_project}"

  services = [
    "iam.googleapis.com",
    "compute-component.googleapis.com",
    "container.googleapis.com",
    "servicemanagement.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
  ]
}

resource "google_compute_network" "openvpn_network" {
  name                    = "${var.prefix}-network"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "openvpn_subnet" {
  name          = "${var.prefix}-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = "${google_compute_network.openvpn_network.self_link}"
  region        = "${var.region}"
}

resource "google_container_cluster" "openvpn_cluster" {
  name               = "${var.prefix}--cluster"
  zone               = "us-east1-b"
  initial_node_count = "1"
  network            = "${google_compute_network.openvpn_network.name}"
  subnetwork         = "${google_compute_subnetwork.openvpn_subnet.name}"

  node_config {
    machine_type = "n1-standard-1"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  monitoring_service = "monitoring.googleapis.com"

  master_auth {
    username = "${var.cluster_master_username}"
    password = "${var.cluster_master_password}"
  }
}

resource "google_compute_address" "openvpn_ingress" {
  name    = "${var.prefix}-ingress"
  project = "${var.google_project}"
}

module "kubernetes_openvpn_deployment" {
  source                 = "modules/kuberbetes_deploy"
  cluster_server         = "${google_container_cluster.openvpn_cluster.endpoint}"
  endpoint_server        = "${google_compute_address.openvpn_ingress.address}"
  username               = "${var.cluster_master_username}"
  password               = "${var.cluster_master_password}"
  cluster_ca_certificate = "${file("./pki/ca.crt")}"
  configuration          = "${file("k8s/deployment.yaml")}"
}

resource "kubernetes_service" "openvpn_service" {
  metadata {
    name = "terraform-gke-openvpn"

    labels {
      openvpn = "terraform-gke-openvpn"
    }
  }

  spec {
    type = "NodePort"

    selector {
      openvpn = "${google_compute_address.openvpn_ingress.address}"
    }

    session_affinity = "ClientIP"

    port {
      protocol    = "TCP"
      port        = 1194
      target_port = 1194
    }
  }
}

resource "kubernetes_secret" "openvpn_pki" {
  depends_on = ["null_resource.kubectl_config"]

  metadata {
    name = "openvpn-pki"
  }

  data {
    private.key     = "${file("./pki/private/${google_compute_address.openvpn_ingress.address}.key")}}"
    ca.crt          = "${file("./pki/ca.crt")}"
    certificate.crt = "${file("./pki/issued/${google_compute_address.openvpn_ingress.address}.crt")}}"
    dh.pem          = "${file("./pki/dh.pem")}"
    ta.key          = "${file("./pki/ta.key")}"
  }

  type = "Opaque"
}

resource null_resource "kubectl_setup" {
  provisioner "local-exec" {
    command = "k8s/install-kubectl.sh"
  }
}

resource null_resource "kubectl_config" {
  depends_on = ["null_resource.kubectl_setup"]

  provisioner "local-exec" {
    command = "k8s/config-kube.sh ${google_container_cluster.openvpn_cluster.endpoint} ${google_compute_address.openvpn_ingress.address}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "k8s/destroy-kube.sh"
  }
}

resource "google_storage_bucket" "openvpn_bucket" {
  name = "${var.prefix}-gcp-bucket"
}

resource "google_storage_bucket" "state-store" {
  name = "${var.prefix}-terraform-state"
}

terraform {
  backend "gcs" {}
}

data "terraform_remote_state" "remote_state" {
  backend = "gcs"

  config {
    bucket      = "${var.prefix}-terraform-state"
    path        = "${var.prefix}/terraform.tfstate"
    project     = "${var.google_project}"
    credentials = "${file("~/.gcp/${var.google_project}.json")}"
  }
}
