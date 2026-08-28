variable "subnet_public_cidr" {}
variable "subnet_private_cidr" {}

/**
 * 第2回で作ったネットワーク
 */
resource "google_compute_network" "vpc" {
  name                    = "${var.user_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "public" {
  name          = "${var.user_name}-public-subnet"
  network       = google_compute_network.vpc.id
  region        = "asia-northeast1"
  ip_cidr_range = var.subnet_public_cidr
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.user_name}-private-subnet"
  network       = google_compute_network.vpc.id
  region        = "asia-northeast1"
  ip_cidr_range = var.subnet_private_cidr

  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  name    = "${var.user_name}-router"
  network = google_compute_network.vpc.id
  region  = "asia-northeast1"
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.user_name}-nat"
  router = google_compute_router.router.name
  region = "asia-northeast1"

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

/**
 * 第3回: webインスタンス
 */
/**
 * webインスタンス用サービスアカウント
 */
resource "google_service_account" "web" {
  account_id   = "${var.user_name}-web"
  display_name = "${var.user_name} web instance"
}

/**
 * webインスタンス作成
 *
 * 外部IPを持たせない。インターネットへの出口は第2回で作ったCloud NAT。
 * 外部からのアクセスは、このあと作るロードバランサ経由にする。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
 */
resource "google_compute_instance" "web" {
  name = "${var.user_name}-web"

  // 第3回と同じ e2-medium。
  // Spanner のクライアントライブラリ(Google Cloud Go SDK + gRPC)は
  // 依存がさらに大きく、e2-micro では現実的な時間でビルドできない。
  machine_type = "e2-medium"

  zone = "asia-northeast1-a"

  tags = ["${var.user_name}-web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"

      // Persistent Disk のサイズと種類
      // pd-balanced はSSDとHDDの中間。省略時のデフォルト
      size = 10
      type = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
    // access_configを書かない = 外部IPなし
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = google_service_account.web.email
    scopes = ["cloud-platform"]
  }
}

/**
 * 第3回: IAP用Firewall
 */
/**
 * IAP TCP forwarding からのSSHを許可(第2回と同じ)
 */
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.user_name}-allow-iap-ssh"
  network = google_compute_network.vpc.name

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.user_name}-web"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

/**
 * 第3回: ロードバランサ用Firewall
 */
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
  network = google_compute_network.vpc.name

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

/**
 * 第3回: IAP関連のIAM
 */
/**
 * IAP経由でVMに入るための権限(第2回と同じ3点セット)
 */
data "google_client_openid_userinfo" "me" {}

resource "google_iap_tunnel_instance_iam_member" "web" {
  zone     = google_compute_instance.web.zone
  instance = google_compute_instance.web.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = "user:${data.google_client_openid_userinfo.me.email}"
}

resource "google_compute_instance_iam_member" "web_os_login" {
  zone          = google_compute_instance.web.zone
  instance_name = google_compute_instance.web.name
  role          = "roles/compute.osAdminLogin"
  member        = "user:${data.google_client_openid_userinfo.me.email}"
}

resource "google_service_account_iam_member" "web_sa_user" {
  service_account_id = google_service_account.web.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${data.google_client_openid_userinfo.me.email}"
}

/**
 * 第3回: ロードバランサ
 */
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


/**
 * 第3回: Cloud DNS
 */
variable "dns_zone_name" {}

/**
 * Cloud DNS のマネージドゾーンを参照する
 *
 * ★ ゾーンはTerraformで作らない ★
 * 全員で1つのプロジェクトを共有しているため、
 * ゾーンをresourceで書くと誰かのdestroyで全員のドメインが消える。
 * 事前に用意されたゾーンをdataで参照するだけにする。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/dns_managed_zone
 */
data "google_dns_managed_zone" "public" {
  name = var.dns_zone_name
}

/**
 * Aレコード作成
 *
 * <自分の名前>.<勉強会のドメイン> を
 * ロードバランサのグローバルIPに向ける。
 *
 * AWSではALBへの alias レコードだったが、
 * GCPはLBが固定IPを持つので普通のAレコードでよい。
 *
 * dns_name は末尾にドットが付く形("example.jp.")で返る。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set
 */
resource "google_dns_record_set" "web" {
  name         = "${var.user_name}.${data.google_dns_managed_zone.public.dns_name}"
  managed_zone = data.google_dns_managed_zone.public.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_address.web.address]
}


/**
 * 第3回: マネージドSSL証明書
 */
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



/**
 * 第4回以降から参照するための output
 */

/**
 * 第4回以降から参照するための output
 */
output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "private_subnet_id" {
  value = google_compute_subnetwork.private.id
}

output "web_instance_name" {
  value = google_compute_instance.web.name
}

output "web_instance_zone" {
  value = google_compute_instance.web.zone
}

output "web_service_account_email" {
  value = google_service_account.web.email
}

output "lb_ip" {
  value = google_compute_global_address.web.address
}

output "web_https_url" {
  value = "https://${var.user_name}.${trimsuffix(data.google_dns_managed_zone.public.dns_name, ".")}"
}
