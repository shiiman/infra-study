/**
 * ロードバランサ(Global External Application Load Balancer)
 *
 * AWSのALBは lb + target group + listener の3リソースで済んだが、
 * GCPは役割ごとにリソースが分かれていて6つ必要になる。
 *
 *   グローバル外部IP  ── 転送ルール ── ターゲットプロキシ ── URLマップ
 *                                                              │
 *                                        バックエンドサービス ──┘
 *                                          ├ ヘルスチェック
 *                                          └ インスタンスグループ ── VM
 *
 * 多く見えるが、1つ1つの役割は単純。上から順に作っていく。
 */

/**
 * インスタンスグループ
 *
 * AWSはターゲットグループにEC2を直接アタッチできたが、
 * GCPのバックエンドサービスはVMを直接持てない。
 * 必ずインスタンスグループ(またはNEG)を挟む。
 *
 * ここでは手動管理の非マネージドインスタンスグループを使う。
 * 自動でスケールするMIG(マネージドインスタンスグループ)は概説のみ。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_group
 */
resource "google_compute_instance_group" "web" {
  name = "${var.user_name}-web-ig"
  zone = "asia-northeast1-a"

  instances = [google_compute_instance.web.id]

  // コンテナは8080で動いているが、80で受けて8080へ流すのではなく
  // ホストの80をコンテナの8080にマッピングしている(docker run -p 80:8080)
  named_port {
    name = "http"
    port = 80
  }
}

/**
 * ヘルスチェック
 *
 * AWSではターゲットグループの設定項目だったが、GCPは独立したリソース。
 * 複数のバックエンドサービスで使い回せる。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check
 */
resource "google_compute_health_check" "web" {
  name = "${var.user_name}-web-hc"

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

/**
 * バックエンドサービス
 *
 * AWSのターゲットグループに相当する。
 * どのインスタンスグループへ、どのポートで、どう振り分けるかを決める。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service
 */
resource "google_compute_backend_service" "web" {
  name        = "${var.user_name}-web-bs"
  protocol    = "HTTP"
  port_name   = "http" // インスタンスグループのnamed_portを指定
  timeout_sec = 30

  health_checks = [google_compute_health_check.web.id]

  backend {
    group = google_compute_instance_group.web.id
  }
}

/**
 * URLマップ
 *
 * パスによって振り分け先を変える機能。AWSのリスナールールに相当する。
 * 今回は振り分けをしないので、全部をバックエンドサービスへ流すだけ。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map
 */
resource "google_compute_url_map" "web" {
  name            = "${var.user_name}-web-urlmap"
  default_service = google_compute_backend_service.web.id
}

/**
 * ターゲットHTTPプロキシ
 *
 * 転送ルールとURLマップをつなぐ部品。プロトコルごとに種類がある。
 * HTTPSにするときは target_https_proxy に差し替える(Step4)。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy
 */
resource "google_compute_target_http_proxy" "web" {
  name    = "${var.user_name}-web-http-proxy"
  url_map = google_compute_url_map.web.id
}

/**
 * グローバル外部IPアドレス
 *
 * AWSのALBはDNS名しか払い出されなかったが、GCPは固定IPを取る。
 * このIPをDNSのAレコードに登録する(Step3)。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address
 */
resource "google_compute_global_address" "web" {
  name = "${var.user_name}-web-ip"
}

/**
 * グローバル転送ルール
 *
 * 「どのIPの、どのポートに来た通信を、どのプロキシへ渡すか」を決める入口。
 *
 * provider 8.0 から load_balancing_scheme の既定値が
 * EXTERNAL_MANAGED になった(グローバル外部アプリケーションLB)。
 * ネット上の古いサンプルには EXTERNAL と明示してあるものが多いが、
 * 今は書かなくてよい。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule
 */
resource "google_compute_global_forwarding_rule" "web_http" {
  name       = "${var.user_name}-web-http-fr"
  target     = google_compute_target_http_proxy.web.id
  ip_address = google_compute_global_address.web.id
  port_range = "80"
}

output "lb_ip" {
  value = google_compute_global_address.web.address
}
