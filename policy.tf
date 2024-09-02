# Example Policy: Restricting access to certain ports
resource "google_project_iam_member" "restrict_port" {
  project = "<your-project-id>"
  role    = "roles/compute.viewer"
  member  = "user:<your-email>"

  condition {
    title       = "restrict-port"
    description = "Restrict access to port 80"
    expression  = "resource.name.startsWith('projects/1234567890/global/firewalls/allow-port-80')"
  }
}
