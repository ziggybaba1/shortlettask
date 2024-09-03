# Grafana Helm Chart Installation if it doesn't exist
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.default.metadata[0].name

  set {
    name  = "adminPassword"
    value = "admin"
  }

  lifecycle {
    prevent_destroy = true
  }
}
