/**
 * サーバレスNEG(ネットワークエンドポイントグループ)
 *
 * ロードバランサのバックエンドに Cloud Run をぶら下げるための部品。
 *
 * ★ 第3回でやったインスタンスグループの代わり ★
 *
 *   第3回  バックエンドサービス → インスタンスグループ → VM
 *   今回    バックエンドサービス → サーバレスNEG      → Cloud Run
 *
 * ヘルスチェックも要らない。Cloud Run 側が面倒を見てくれる。
 * 第3回でハマった 130.211.0.0/22 の Firewall Rule も不要。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_network_endpoint_group
 */
resource "google_compute_region_network_endpoint_group" "run" {
  name                  = "${var.user_name}-run-neg"
  region                = "asia-northeast1"
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.app.name
  }
}

/**
 * Cloud Run 用のバックエンドサービス
 *
 * ★ 第3回のバックエンドサービスとの違い ★
 *   health_checks が無い(サーバレスNEGには不要)
 *   port_name も無い
 */
resource "google_compute_backend_service" "run" {
  name     = "${var.user_name}-run-bs"
  protocol = "HTTP"

  backend {
    group = google_compute_region_network_endpoint_group.run.id
  }
}

/**
 * URLマップ
 *
 * ★ ここが今日のハイライト ★
 *
 * 第3回で作った グローバルIP / SSL証明書 / DNSレコード はそのまま使う。
 * URLマップの向き先を Cloud Run のバックエンドサービスにするだけで、
 * 同じドメイン・同じ証明書のまま中身が VM から Cloud Run に入れ替わる。
 *
 * VMのバックエンドサービスは残してある(0. before の中)。
 * 問題があれば default_service を戻すだけでロールバックできる。
 * 実際の移行でもこの手順を取る。
 */
resource "google_compute_url_map" "main" {
  name            = "${var.user_name}-urlmap"
  default_service = google_compute_backend_service.run.id
}

resource "google_compute_target_https_proxy" "main" {
  name             = "${var.user_name}-https-proxy"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = [module.before.ssl_certificate_id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name       = "${var.user_name}-https-fr"
  target     = google_compute_target_https_proxy.main.id
  ip_address = module.before.global_address_id
  port_range = "443"
}

output "web_https_url" {
  value = module.before.web_https_url
}
