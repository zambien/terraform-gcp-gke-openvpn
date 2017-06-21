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

provider "kubernetes" {
  username = "${var.cluster_master_username}"
  password = "${var.cluster_master_password}"
}

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
    "dns.googleapis.com"
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
      "https://www.googleapis.com/auth/service.management"
    ]
  }

  monitoring_service = "monitoring.googleapis.com"

  master_auth {
    username = "${var.cluster_master_username}"
    password = "${var.cluster_master_password}"
  }
}

resource "google_compute_global_address" "openvpn_ingress" {
  name    = "${var.prefix}-ingress"
  project = "${var.google_project}"
}

module "kubernetes_openvpn_deployment" {
  source                 = "modules/kuberbetes_deploy"
  cluster_server         = "${google_container_cluster.openvpn_cluster.endpoint}"
  endpoint_server        = "${google_compute_global_address.openvpn_ingress.address}"
  username               = "${var.cluster_master_username}"
  password               = "${var.cluster_master_password}"
  cluster_ca_certificate = "${module.pki.ca_crt}"
  secret_uid             = "${kubernetes_secret.openvpn_pki.id}}"
}

module "pki" {
  source          = "modules/pki"
  endpoint_server = "${google_compute_global_address.openvpn_ingress.address}"
}

/* This does not currently work correctly.
 * Ports are not respected/used and load balancers sometimes are not deleted on destroy.  Doing this in the module for now.
 * Not too surprising given how new the kubernetes provider is.

resource "kubernetes_service" "openvpn_service" {
  depends_on = ["module.kubernetes_openvpn_deployment"]
  metadata {
    name = "terraform-gke-openvpn"

    labels {
      openvpn = "terraform-gke-openvpn"
    }
  }

  spec {
    type = "NodePort"


    selector {
        openvpn = "${google_compute_global_address.openvpn_ingress.address}"
    }

    session_affinity = "ClientIP"

    port {
      protocol    = "TCP"
      port        = 8080
      target_port = 1194
    }
  }
}*/

resource "kubernetes_secret" "openvpn_pki" {
  metadata {
    name = "openvpn-pki"
  }

  data {
    private.key     = "${module.pki.private_key}"
    ca.crt          = "${module.pki.ca_crt}"
    certificate.crt = "${module.pki.certificate_crt}"
    dh.pem          = "${module.pki.dh_pem}"
    ta.key          = "${module.pki.ta_key}"
  }

  type = "Opaque"
}

