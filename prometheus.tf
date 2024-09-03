# Check if Prometheus exists using a data block
data "helm_release" "existing_prometheus" {
  name = "prometheus"
  namespace = kubernetes_namespace.default.metadata[0].name
}

# Prometheus Helm Chart Installation if it doesn't exist
resource "helm_release" "prometheus" {
  count = length(data.helm_release.existing_prometheus.id) == 0 ? 1 : 0
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.default.metadata[0].name
}
