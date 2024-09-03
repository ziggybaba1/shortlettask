resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]  # Removed port 22 (SSH) for security
  }

  # This range should match your subnet CIDR
  source_ranges = ["10.0.0.0/24"]  

  # Added a description for better documentation
  description = "Allows internal traffic on specified ports"

  # Added target tags for more granular control
  target_tags = ["web-server"]

  # Removed the prevent_destroy lifecycle rule
}