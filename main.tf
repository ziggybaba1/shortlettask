provider "google" {
  project     = "sixth-syntax-434405-p0"
  region      = "us-central1"
}

# Create VPC
resource "google_compute_network" "vpc_network" {
  name = "my-vpc"
  auto_create_subnetworks = false
}

# Create Subnet
# resource "google_compute_subnetwork" "subnetwork" {
#   name          = "my-subnetwork"
#   ip_cidr_range = "10.0.0.0/16"
#   network       = google_compute_network.vpc_network.name
#   region        = "us-central1"
# }

# resource "google_compute_disk" "default" {
#   name  = "my-disk"
#   type  = "pd-ssd"
#   zone  = "us-central1-a"
#   size  = 150  # Reduced from 900 GB to 250 GB
# }

# Create GKE Cluster
# resource "google_container_cluster" "primary" {
#   name               = "gke-cluster"
#   location           = "us-central1"
#   initial_node_count = 1

#   network    = google_compute_network.vpc_network.name
#   subnetwork = google_compute_subnetwork.subnetwork.name

#   node_config {
#     machine_type = "e2-medium"
#     oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
#   }
# }

# NAT Gateway Setup
resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  network = google_compute_network.vpc_network.name
  region  = "us-central1"
}

resource "google_compute_router_nat" "nat_config" {
  name            = "nat-config"
  router          = google_compute_router.nat_router.name
  region          = "us-central1"
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Kubernetes Namespace
resource "kubernetes_namespace" "default" {
  metadata {
    name = "shortlet-namespace"
  }
}

# Kubernetes Deployment
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
          image = "gcr.io/ziggybaba/php-api:latest"
          name  = "php-api"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Kubernetes Service
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
