# Configure Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Get default client config
data "google_client_config" "default" {}

# Check if VPC Network already exists
data "google_compute_network" "existing_vpc_network" {
  name = "shortlet-vpc-network"
}

# Define local variable for conditional creation
locals {
  network_exists = length(data.google_compute_network.existing_vpc_network.*.name) > 0
}

# Define VPC Network (explicit creation)
# Define a conditional VPC creation
resource "google_compute_network" "vpc_network" {
  count = local.network_exists ? 0 : 1
  name  = "shortlet-vpc-network"
  auto_create_subnetworks = false
}

# Ensure the firewall rule depends on the network creation
resource "google_compute_firewall" "allow_http" {
  count = local.network_exists ? 0 : 1  # Only create if the network is created
  name  = "allow-http"
  network = google_compute_network.vpc_network[0].id
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  depends_on = [google_compute_network.vpc_network]
}

# GKE Cluster Creation
resource "google_container_cluster" "primary" {
   count = local.network_exists ? 0 : 1
  name     = "shortlet-cluster"
  location = var.region
  network  = google_compute_network.vpc_network[0].id
  initial_node_count = 3

  # Ensure the cluster is created before referencing it
  depends_on = [google_compute_network.vpc_network]
}

# Node Pool creation with conditional checks
resource "google_container_node_pool" "primary_nodes" {
  count = local.network_exists ? 0 : 1  # Only create if the cluster exists
  name = "shortlet-pool"
  cluster = google_container_cluster.primary[0].name
  node_count = 1

  node_config {
    machine_type = "e2-small"
    preemptible  = true

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  depends_on = [google_container_cluster.primary]
}


# Ensure Kubernetes provider depends on the GKE cluster creation
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Ensure Helm provider depends on the GKE cluster creation
provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}

resource "null_resource" "dependency" {
  depends_on = [google_container_cluster.primary]
}

# Kubernetes Resources
resource "kubernetes_namespace" "api_namespace" {
  metadata {
    name = "api-namespace"
  }
  depends_on = [google_container_cluster.primary]
}


resource "kubernetes_deployment" "api_deployment" {
  metadata {
    name      = "api-deployment"
    namespace = kubernetes_namespace.api_namespace.metadata[0].name
  }

  spec {
    replicas = 2

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

resource "kubernetes_service" "api_service" {
  metadata {
    name      = "api-service"
    namespace = kubernetes_namespace.api_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_deployment.api_deployment.spec[0].template[0].metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

# Deploy Helm Charts
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "monitoring"
  version    = "6.50.7"

  set {
    name  = "adminPassword"
    value = "admin"
  }

  depends_on = [google_container_cluster.primary, kubernetes_namespace.api_namespace]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = "monitoring"
  version    = "15.10.1"

  depends_on = [google_container_cluster.primary, kubernetes_namespace.api_namespace]
}
