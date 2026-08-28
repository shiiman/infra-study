/**
 * Googleマネージド SSL証明書
 *
 * AWSのACMに相当する。無料で、期限が来ると自動更新される。
 *
 * ★ AWSとの違い ★
 * ACMでは「DNS検証用のCNAMEレコードを自分で作る」必要があったが、
 * GCPは対象ドメインがこのロードバランサを向いていることを
 * Google側が確認して自動で発行する。検証レコードを作る作業がない。
 *
 * ★ 注意 ★
 * 発行(PROVISIONING → ACTIVE)まで数十分かかることがある。
 * 先にAレコードが引ける状態になっている必要があるので、
 * Step3(DNS)を必ず先に済ませておくこと。
 *
 * また、このリソースは name を変更すると再作成になり、
 * また数十分待つことになる。lifecycle で作ってから消す順序にしている。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_managed_ssl_certificate
 */
resource "google_compute_managed_ssl_certificate" "web" {
  name = "${var.user_name}-web-cert"

  managed {
    domains = ["${var.user_name}.${data.google_dns_managed_zone.public.dns_name}"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

/**
 * ターゲットHTTPSプロキシ
 *
 * Step2で作った target_http_proxy のHTTPS版。
 * 証明書をここにぶら下げる。URLマップは同じものを使い回せる。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy
 */
resource "google_compute_target_https_proxy" "web" {
  name             = "${var.user_name}-web-https-proxy"
  url_map          = google_compute_url_map.web.id
  ssl_certificates = [google_compute_managed_ssl_certificate.web.id]
}

/**
 * 443番の転送ルール
 *
 * 80番の転送ルール(Step2)はそのまま残す。
 * 同じIPアドレスに、ポートごとに転送ルールをぶら下げる形になる。
 */
resource "google_compute_global_forwarding_rule" "web_https" {
  name       = "${var.user_name}-web-https-fr"
  target     = google_compute_target_https_proxy.web.id
  ip_address = google_compute_global_address.web.id
  port_range = "443"
}

output "web_https_url" {
  value = "https://${var.user_name}.${trimsuffix(data.google_dns_managed_zone.public.dns_name, ".")}"
}
