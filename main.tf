# Configure Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Get default client config
data "google_client_config" "default" {}

# Define VPC Network (explicit creation)
resource "google_compute_network" "vpc_network" {
  name                    = "my-vpc-network"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Define Subnet (explicit creation)
resource "google_compute_subnetwork" "subnet" {
  name          = "my-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
  project       = var.project_id
}

# Define Router and NAT Gateway (explicit creation)
resource "google_compute_router" "router" {
  name    = "my-router"
  region  = var.region
  network = google_compute_network.vpc_network.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "my-router-nat"
  router                             = google_compute_router.router[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Define Firewall Rule (allow only HTTP)
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Define GKE Cluster
resource "google_container_cluster" "primary" {
  name             = "my-gke-cluster"
  location         = var.region
  initial_node_count = 3
  network    = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.subnet.id
}

# Define GKE Node Pool with adjustments
resource "google_container_node_pool" "primary_nodes" {
  
  name       = "my-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-small"

    disk_size_gb = 50  # Reduced from default 100GB
    disk_type    = "pd-standard"  # Changed from SSD to standard persistent disk

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    tags = ["web-server"]
  }
}

# Configure Kubernetes Providers
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}

# Kubernetes Resources (consider separate files for complex deployments)
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

# Deploy Helm Charts with updated versions
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "monitoring"
  version    = "6.50.7"  # Update to the latest stable version

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
  version    = "15.10.1"  # Update to the latest stable version

  depends_on = [google_container_cluster.primary, kubernetes_namespace.api_namespace]
}