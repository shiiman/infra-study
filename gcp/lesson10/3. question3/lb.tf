/**
 * 問3 模範解答: ロードバランサ
 *
 * 出題範囲: 第3回
 *
 * ★ 採点のポイント ★
 *   1. 6つの部品が揃っているか
 *      インスタンスグループ / ヘルスチェック / バックエンドサービス /
 *      URLマップ / ターゲットHTTPプロキシ / グローバル転送ルール
 *   2. グローバルIPを予約しているか
 *   3. インスタンスグループに named_port(http/80)があるか
 *      → これが無いとバックエンドサービスがポートを解決できない
 *   4. 2台とも instances に入っているか
 *
 * ★ HTTP で作らせている理由 ★
 *   HTTPS にすると Google マネージド証明書の発行に7〜10分かかる。
 *   60分の試験には収まらないので、この問題は HTTP(80番)にしている。
 *   → 部品は5つ(ターゲットHTTPプロキシ)。HTTPSなら証明書が増えて6つ。
 */

/**
 * インスタンスグループ
 *
 * ロードバランサは「VM」を直接見ない。
 * インスタンスグループという箱を経由する(第3回 S25)。
 */
resource "google_compute_instance_group" "web" {
  name = "${var.user_name}-web-ig"
  zone = "asia-northeast1-a"

  instances = google_compute_instance.web[*].self_link

  // ★ これが無いとバックエンドサービスがポートを解決できない
  named_port {
    name = "http"
    port = 80
  }
}

/**
 * ヘルスチェック
 *
 * 130.211.0.0/22 と 35.191.0.0/16 から飛んでくる。
 * 問4の Firewall ルールでこのレンジを開ける必要がある。
 */
resource "google_compute_health_check" "web" {
  name = "${var.user_name}-web-hc"

  check_interval_sec = 10
  timeout_sec        = 5

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

resource "google_compute_backend_service" "web" {
  name        = "${var.user_name}-web-bs"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  health_checks = [google_compute_health_check.web.id]

  backend {
    group = google_compute_instance_group.web.id
  }
}

/**
 * URLマップ
 *
 * 今回は振り分けをしないので default_service だけ。
 * (第6回でパスルールを使った)
 */
resource "google_compute_url_map" "main" {
  name            = "${var.user_name}-urlmap"
  default_service = google_compute_backend_service.web.id
}

resource "google_compute_target_http_proxy" "main" {
  name    = "${var.user_name}-http-proxy"
  url_map = google_compute_url_map.main.id
}

resource "google_compute_global_address" "web" {
  name = "${var.user_name}-web-ip"
}

resource "google_compute_global_forwarding_rule" "http" {
  name       = "${var.user_name}-http-fr"
  target     = google_compute_target_http_proxy.main.id
  ip_address = google_compute_global_address.web.id
  port_range = "80"
}

output "lb_ip" {
  value = google_compute_global_address.web.address
}

output "lb_url" {
  value = "http://${google_compute_global_address.web.address}/"
}
