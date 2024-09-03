# Check if Grafana exists using a data block
data "helm_release" "existing_grafana" {
  name = "grafana"
  namespace = kubernetes_namespace.default.metadata[0].name
}

# Grafana Helm Chart Installation if it doesn't exist
resource "helm_release" "grafana" {
  count = length(data.helm_release.existing_grafana.id) == 0 ? 1 : 0
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.default.metadata[0].name

  set {
    name  = "adminPassword"
    value = "admin"
  }
}
