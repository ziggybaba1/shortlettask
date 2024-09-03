provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = google_container_cluster.primary[0].endpoint
  cluster_ca_certificate = base64decode(google_container_cluster.primary[0].master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

# Check if the VPC network already exists using a data block
data "google_compute_network" "existing_network" {
  name    = "my-vpc"
  project = var.project_id
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
  network = data.google_compute_network.existing_network.id
}

# Create Subnet if it doesn't exist
resource "google_compute_subnetwork" "subnetwork" {
  count         = length(data.google_compute_subnetwork.existing_subnetwork.id) == 0 ? 1 : 0
  name          = "my-subnetwork"
  ip_cidr_range = "10.0.0.0/16"
  network       = google_compute_network.vpc_network[0].id
  region        = var.region
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  count              = length(data.google_container_cluster.existing_cluster.id) == 0 ? 1 : 0
  name               = "gke-cluster"
  location           = var.region
  initial_node_count = 3
  network            = google_compute_network.vpc_network[0].self_link
  subnetwork         = google_compute_subnetwork.subnetwork[0].self_link

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-range"
    services_secondary_range_name = "services-range"
  }

  master_auth {
    username = ""
    password = ""
    client_certificate_config {
      issue_client_certificate = false
    }
  }
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

# Helm Release for Grafana
resource "helm_release" "existing_grafana" {
  name       = "grafana"
  chart      = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  namespace  = kubernetes_namespace.default.metadata[0].name
  version    = "6.16.10"
}

# Helm Release for Prometheus
resource "helm_release" "existing_prometheus" {
  name       = "prometheus"
  chart      = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  namespace  = kubernetes_namespace.default.metadata[0].name
  version    = "14.11.1"
}
