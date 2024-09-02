output "kubernetes_cluster_name" {
  description = "The name of the Kubernetes cluster"
  value       = google_container_cluster.primary.name
}

output "api_endpoint" {
  description = "The endpoint of the API"
  value       = kubernetes_service.api_service.status[0].load_balancer[0].ingress[0].ip
}
