resource "google_compute_firewall" "no_ssh" {
  count = length(google_compute_network.vpc_network) > 0 ? 1 : 0
  name  = "no-ssh"
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction = "INGRESS"
  disabled  = true
}
