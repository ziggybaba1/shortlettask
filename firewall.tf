resource "google_compute_firewall" "no_ssh" {
  name    = "no-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction = "INGRESS"
  disabled  = true
}
