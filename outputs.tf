output "network_created" {
  value = google_compute_network.vpc_network.*.name
}