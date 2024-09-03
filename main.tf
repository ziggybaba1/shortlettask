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

# Check if the VPC network exists using a data block
data "google_compute_network" "existing_network" {
  name    = "my-vpc"
  project = var.project_id
}

# Create VPC if it doesn't exist
resource "google_compute_network" "vpc_network" {
  count   = length(data.google_compute_network.existing_network) == 0 ? 1 : 0
  name    = "my-vpc"
  project = var.project_id
}

# Check if the Subnetwork exists using a data block
data "google_compute_subnetwork" "existing_subnetwork" {
  name    = "my-subnetwork"
  region  = var.region
  project = var.project_id
}

# Create Subnetwork if it doesn't exist
resource "google_compute_subnetwork" "subnetwork" {
  count         = length(data.google_compute_subnetwork.existing_subnetwork) == 0 ? 1 : 0
  name          = "my-subnetwork"
  ip_cidr_range = "10.0.0.0/16"
  network       = length(data.google_compute_network.existing_network) > 0 ? data.google_compute_network.existing_network.id : google_compute_network.vpc_network[0].id
  region        = var.region
  project       = var.project_id
}

# Check if the GKE Cluster exists using a data block
data "google_container_cluster" "existing_cluster" {
  name     = "gke-cluster"
  location = var.region
  project  = var.project_id
}

# Create GKE Cluster if it doesn't exist
resource "google_container_cluster" "primary" {
  count              = length(data.google_container_cluster.existing_cluster) == 0 ? 1 : 0
  name               = "gke-cluster"
  location           = var.region
  initial_node_count = 3
  network            = length(data.google_compute_network.existing_network) > 0 ? data.google_compute_network.existing_network.id : google_compute_network.vpc_network[0].id
  subnetwork         = length(data.google_compute_subnetwork.existing_subnetwork) > 0 ? data.google_compute_subnetwork.existing_subnetwork.id : google_compute_subnetwork.subnetwork[0].id

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-range"
    services_secondary_range_name = "services-range"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

# Check if the NAT Router exists using a data block
data "google_compute_router" "existing_nat_router" {
  name    = "nat-router"
  network = length(data.google_compute_network.existing_network) > 0 ? data.google_compute_network.existing_network.name : google_compute_network.vpc_network[0].name
  region  = var.region
  project = var.project_id
}

# Create NAT Router if it doesn't exist
resource "google_compute_router" "nat_router" {
  count   = length(data.google_compute_router.existing_nat_router) == 0 ? 1 : 0
  name    = "nat-router"
  network = length(data.google_compute_network.existing_network) > 0 ? data.google_compute_network.existing_network.id : google_compute_network.vpc_network[0].id
  region  = var.region
  project = var.project_id
}

# Create NAT Gateway if it doesn't exist
resource "google_compute_router_nat" "nat_config" {
  count                              = length(data.google_compute_router.existing_nat_router) == 0 ? 1 : 0
  name                               = "nat-config"
  router                             = google_compute_router.nat_router[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  project                            = var.project_id
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
resource "helm_release" "grafana" {
  name       = "grafana"
  chart      = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  namespace  = "monitoring"
  version    = "6.16.10"
  set {
    name  = "adminPassword"
    value = "admin"
  }
}

# Helm Release for Prometheus
resource "helm_release" "prometheus" {
  name       = "prometheus"
  chart      = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  namespace  = "monitoring"
  version    = "14.11.1"
}