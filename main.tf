provider "google" {
  project     = var.project_id
  region      = var.region
}

# Create VPC if it doesn't exist
resource "google_compute_network" "vpc_network" {
  name = "my-vpc"
  lifecycle {
    prevent_destroy = true
  }
}

# Create Subnet if it doesn't exist
resource "google_compute_subnetwork" "subnetwork" {
  name          = "my-subnetwork"
  ip_cidr_range = "10.0.0.0/16"
  network       = google_compute_network.vpc_network.name
  region        = var.region
  lifecycle {
    prevent_destroy = true
  }
}

# Create GKE Cluster only if it doesn't exist
resource "google_container_cluster" "primary" {
  name               = "gke-cluster"
  location           = var.region
  initial_node_count = 3

  network    = google_compute_network.vpc_network.name
  subnetwork = google_compute_subnetwork.subnetwork.name

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  lifecycle {
    prevent_destroy = true
  }
}

# NAT Gateway Setup if it doesn't exist
resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  network = google_compute_network.vpc_network.name
  region  = var.region
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_router_nat" "nat_config" {
  name            = "nat-config"
  router          = google_compute_router.nat_router.name
  region          = var.region
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  lifecycle {
    prevent_destroy = true
  }
}

# Kubernetes Namespace, avoid recreation
resource "kubernetes_namespace" "default" {
  metadata {
    name = "shortlet-namespace"
  }
  lifecycle {
    prevent_destroy = true
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
          image = "hub.docker.com/repository/docker/ziggybaba/php-api:latest"
          name  = "php-api"

          port {
            container_port = 80
          }
        }
      }
    }
  }
  lifecycle {
    prevent_destroy = true
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
  lifecycle {
    prevent_destroy = true
  }
}
