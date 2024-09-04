terraform {
  required_providers {
    google= {
      source ="hashicorp/google",
      version = "~> 4.0"
    }
    kubernetes={
      source="hashicorp/kubernetes"
    }
  }
}



provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

data "google_compute_network" "existing_vpc" {
  name    = "${var.project_name}-vpc-network"
  project = var.project_id
}
# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project_name}-vpc-network"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_name}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}

# Kubernetes Provider (moved before GKE cluster)
# provider "kubernetes" {
#   host                   = "https://${google_container_cluster.primary.endpoint}"
#   token                  = data.google_client_config.default.access_token
#   cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
# }

data "google_container_cluster" "existing_primary" {
  name = "${var.project_name}-cluster"
}
# GKE cluster
resource "google_container_cluster" "primary" {
  count = length(data.google_container_cluster.existing_primary.*.name) == 0 ? 1:0
  name     = "${var.project_name}-cluster"
  location = var.region
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  count = length(data.google_container_cluster.existing_primary.*.name) == 0 ? 1:0
  name       = "${var.project_name}-pool"
  location   = var.region
  cluster    = google_container_cluster.primary[0].name
  
  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]

    labels = {
      env = var.project_id
    }

    # preemptible  = true
    machine_type = "e2-small"
    disk_size_gb = 50  # Reduced from default 100GB
    disk_type    = "pd-standard"  # Changed from SSD to standard persistent disk
    tags         = ["${var.project_name}-node", "${var.project_name}-cluster","web-server"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

