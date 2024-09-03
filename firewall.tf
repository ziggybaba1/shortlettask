# Define firewall rules for secure communication
# network = google_compute_network.vpc_network.name
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = "my-vpc"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["10.0.0.0/16"]
}
