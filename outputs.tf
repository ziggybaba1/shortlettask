output "kubernetes_cluster_name" {
  description = "The name of the Kubernetes cluster"
  value       = "sixth-syntax-434405-p0"
}

output "api_endpoint" {
  description = "The endpoint of the API"
  value       = kubernetes_service.api_service.status[0].load_balancer[0].ingress[0].ip
}
