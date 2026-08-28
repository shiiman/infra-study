/**
 * IAP TCP forwarding からのSSHを許可(第2回と同じ)
 */
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.user_name}-allow-iap-ssh"
  network = module.before.vpc_name

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.user_name}-web"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
