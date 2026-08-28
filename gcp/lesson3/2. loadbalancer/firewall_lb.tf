/**
 * ロードバランサからwebインスタンスへの通信を許可
 *
 * ★ GCPのロードバランサで一番ハマるところ ★
 *
 * Googleのロードバランサは、次の2つの固定レンジから来る。
 *   130.211.0.0/22
 *   35.191.0.0/16
 *
 * ヘルスチェックも、実際のユーザトラフィックの転送も、両方このレンジから届く。
 * ここを開けていないとヘルスチェックが通らず、
 * バックエンドが永久にUNHEALTHYのままで 502 が返り続ける。
 *
 * AWSでは「LBのSGからwebのSGへ」と書けば済んだが、
 * GCPのロードバランサはVPCの外側にいるのでSG的な発想が使えない。
 * 決められたIPレンジを開ける、という書き方になる。
 *
 * https://cloud.google.com/load-balancing/docs/health-check-concepts
 */
resource "google_compute_firewall" "allow_lb_to_web" {
  name    = "${var.user_name}-allow-lb-to-web"
  network = module.before.vpc_name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]
  target_tags = ["${var.user_name}-web"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}
