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

# Enable APIs for project so terraform can do it's thing
resource "google_project_services" "openvpn_project" {
  project = "${var.google_project}"

  services = [
    "iam.googleapis.com",
    "compute-component.googleapis.com",
    "container.googleapis.com",
    "servicemanagement.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com"
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
    machine_type     = "n1-standard-1"

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

resource "google_storage_bucket" "openvpn_bucket" {
  name     = "${var.prefix}-gcp-bucket"
}

resource "google_storage_bucket" "state-store" {
  name     = "${var.prefix}-terraform-state"
}

terraform {
  backend "gcs" { }
}

data "terraform_remote_state" "remote_state" {
  backend = "gcs"
  config {
    bucket  = "${var.prefix}-terraform-state"
    path    = "${var.prefix}/terraform.tfstate"
    project = "${var.google_project}"
    credentials = "${file("~/.gcp/${var.google_project}.json")}"
  }
}
