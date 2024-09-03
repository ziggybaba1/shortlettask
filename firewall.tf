#  Define Firewall Rule (allow only HTTP)
resource "google_compute_firewall" "allow_http" {
  name    = "shortlet-allow-http"
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
}
