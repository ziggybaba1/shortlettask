provider "google" {
  project     = var.project_id
  region      = var.region
}

# Check if the VPC network already exists using a data block
data "google_compute_network" "existing_network" {
  name = "my-vpc"
}

# Create VPC if it doesn't exist
resource "google_compute_network" "vpc_network" {
  count = length(data.google_compute_network.existing_network.id) == 0 ? 1 : 0
  name  = "my-vpc"
}

# Check if the Subnetwork already exists using a data block
data "google_compute_subnetwork" "existing_subnetwork" {
  name    = "my-subnetwork"
  region  = var.region
}

# Create Subnet if it doesn't exist
resource "google_compute_subnetwork" "subnetwork" {
  count         = length(data.google_compute_subnetwork.existing_subnetwork.id) == 0 ? 1 : 0
  name          = "my-subnetwork"
  ip_cidr_range = "10.0.0.0/16"
  network       = "my-vpc"
  region        = var.region
}


# NAT Gateway Setup if it doesn't exist
data "google_compute_router" "existing_nat_router" {
  name   = "nat-router"
  network = "my-vpc"
  region = var.region
}

resource "google_compute_router" "nat_router" {
  count   = length(data.google_compute_router.existing_nat_router.id) == 0 ? 1 : 0
  name    = "nat-router"
  network = "my-vpc"
  region  = var.region
}

resource "google_compute_router_nat" "nat_config" {
  count                          = length(data.google_compute_router_nat.existing_nat_config.id) == 0 ? 1 : 0
  name                           = "nat-config"
  router                         = "nat-router"
  region                         = var.region
  nat_ip_allocate_option         = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Check if the GKE Cluster already exists using a data block
data "google_container_cluster" "existing_cluster" {
  name     = "gke-cluster"
  location = var.region
}

# Create GKE Cluster if it doesn't exist
resource "google_container_cluster" "primary" {
  count              = length(data.google_container_cluster.existing_cluster.id) == 0 ? 1 : 0
  name               = "gke-cluster"
  location           = var.region
  initial_node_count = 3
  network            = google_compute_network.vpc_network.self_link
  subnetwork         = google_compute_subnetwork.subnetwork.self_link

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-range"
    services_secondary_range_name = "services-range"
  }

  # master_auth {
  #   username = ""
  #   password = ""
  #   client_certificate_config {
  #     issue_client_certificate = false
  #   }
  # }
}

# Create a node pool for the GKE cluster
resource "google_container_node_pool" "primary_nodes" {
  count     = length(data.google_container_cluster.existing_cluster.id) == 0 ? 1 : 0
  cluster   = google_container_cluster.primary[0].name
  location  = var.region
  name      = "primary-node-pool"
  node_count = 3

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

# Kubernetes Namespace, avoid recreation
resource "kubernetes_namespace" "default" {
  metadata {
    name = "shortlet-namespace"
  }
}

# Kubernetes Deployment, create if not exists
resource "kubernetes_deployment" "api_deployment" {
  metadata {
    name      = "api-deployment"
    namespace = kubernetes_namespace.default.metadata[0].name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "api"
      }
    }

    template {
      metadata {
        labels = {
          app = "api"
        }
      }

      spec {
        container {
          image = "docker.io/${var.docker_hub_username}/php-api:latest"
          name  = "php-api"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Kubernetes Service, create if not exists
resource "kubernetes_service" "api_service" {
  metadata {
    name      = "api-service"
    namespace = kubernetes_namespace.default.metadata[0].name
  }

  spec {
    selector = {
      app = "api"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
