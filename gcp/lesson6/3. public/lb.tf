/**
 * URLマップ(パスルール付き)
 *
 * ★ 第3回で「今回は振り分けをしない」と言ったURLマップ ★
 * ここで本領を発揮する。
 *
 *   /static/*  → バックエンドバケット(Cloud Storage + CDN)
 *   それ以外    → バックエンドサービス(Cloud Run)
 *
 * 1つのドメイン・1つの証明書で、静的ファイルとアプリを出し分けられる。
 * AWSでCloudFrontとALBを併用すると、ビヘイビアの設定やオリジンの
 * 使い分けで構成が複雑になるところ。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map
 */
resource "google_compute_url_map" "main" {
  name = "${var.user_name}-urlmap"

  // どのルールにも当たらなかったとき
  default_service = google_compute_backend_service.run.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "main"
  }

  path_matcher {
    name            = "main"
    default_service = google_compute_backend_service.run.id

    // /static/ 以下は Cloud Storage から配信する
    path_rule {
      paths   = ["/static", "/static/*"]
      service = google_compute_backend_bucket.static.id
    }
  }
}

resource "google_compute_target_https_proxy" "main" {
  name    = "${var.user_name}-https-proxy"
  url_map = google_compute_url_map.main.id

  // 第3回で作った証明書をそのまま使う
  ssl_certificates = [google_compute_managed_ssl_certificate.web.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name       = "${var.user_name}-https-fr"
  target     = google_compute_target_https_proxy.main.id
  ip_address = google_compute_global_address.web.id
  port_range = "443"
}



output "static_url" {
  value = "${"https://${var.user_name}.${trimsuffix(data.google_dns_managed_zone.public.dns_name, ".")}"}/static/index.html"
}
