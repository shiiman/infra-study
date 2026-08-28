/**
 * webインスタンスからdbインスタンスへのICMPを許可
 *
 * AWSで source_security_group_id と書いていた部分が、
 * GCPでは source_service_accounts / target_service_accounts になる。
 * 「このサービスアカウントを持つVMから、このサービスアカウントを持つVMへ」
 * という指定の仕方。
 *
 * ネットワークタグでも同じことができるが、タグはVMに自由に付けられるため
 * 「タグを付ければ入れてしまう」という抜け道がある。
 * サービスアカウントの付け替えにはIAM権限が要るので、こちらの方が堅い。
 */
resource "google_compute_firewall" "allow_web_to_db" {
  name    = "${var.user_name}-allow-web-to-db"
  network = google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 1000

  source_service_accounts = [google_service_account.web.email]
  target_service_accounts = [google_service_account.db.email]

  allow {
    protocol = "icmp"
  }
}
