# Prometheus Helm Chart Installation if it doesn't exist
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.default.metadata[0].name

  lifecycle {
    prevent_destroy = true
  }
}
