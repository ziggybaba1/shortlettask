# Example Policy: Restricting access to certain ports
resource "google_project_iam_member" "restrict_port" {
  project = "sixth-syntax-434405-p0"
  role    = "roles/compute.viewer"
  member  = "user:seyiadejugbagbe@gmail.com"

  condition {
    title       = "restrict-port"
    description = "Restrict access to port 80"
    expression  = "resource.name.startsWith('projects/sixth-syntax-434405-p0/global/firewalls/allow-port-80')"
  }
}
