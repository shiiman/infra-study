/**
 * Firewall Rule作成
 *
 * AWSのSecurity Groupとの一番大きな違い:
 * Security Groupは「リソースに貼り付ける壁」だったが、
 * Firewall RuleはVPC単位のルールで、どのVMに効かせるかを
 * 「ネットワークタグ」または「サービスアカウント」で指定する。
 *
 * ※ 1つのルールの中でタグ指定とサービスアカウント指定は混在できない
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall
 */

/**
 * IAP TCP forwarding からのSSHを許可
 *
 * 35.235.240.0/20 はIAPのトンネルが出てくる固定レンジ。
 * このレンジからのtcp:22だけを開けておけば、
 * 踏み台サーバを立てずにprivateなVMへ入れる。
 *
 * ここでは適用先を「ネットワークタグ」で指定している。
 */
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.user_name}-allow-iap-ssh"
  network = google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"]
  target_tags = [
    "${var.user_name}-web",
    "${var.user_name}-db",
  ]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
