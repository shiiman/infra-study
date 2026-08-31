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

/**
 * ターゲットHTTPプロキシ
 *
 * 転送ルールとURLマップをつなぐ部品。プロトコルごとに種類がある。
 * HTTPSにするときは target_https_proxy に差し替える(Step4)。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy
 */

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

/**
 * 443番の転送ルール
 *
 * 80番の転送ルール(Step2)はそのまま残す。
 * 同じIPアドレスに、ポートごとに転送ルールをぶら下げる形になる。
 */



/**
 * 第4回以降から参照するための output
 */

/**
 * 第4回以降から参照するための output
 */

/**
 * 第4回: 限定公開サービスアクセス
 */
/**
 * 限定公開サービスアクセス (Private Service Access)
 *
 * ★ AWSには無い、GCP独自の前提 ★
 *
 * Cloud SQL や Memorystore は「Googleが管理するVPC」の中で動いている。
 * 自分のVPCとは別のネットワークなので、そのままでは繋がらない。
 *
 * そこで自分のVPCの中からIPレンジを1つ切り出してGoogle側に貸し出し、
 * VPCピアリングで両者を繋ぐ。これが限定公開サービスアクセス。
 *
 *   自分のVPC 172.16.0.0/16
 *     ├ public  172.16.0.0/24
 *     ├ private 172.16.10.0/24
 *     └ 172.16.192.0/20  ← Googleに貸し出す(ここにCloud SQLなどのIPが入る)
 *
 * ★ レンジは大きめに取ること ★
 * サービスごとにこのレンジからブロックを切り出して使う。
 * /24 だと Memorystore を作った時点で埋まり、
 * Cloud SQL の作成が次のエラーで失敗する。
 *
 *   Couldn't find free blocks in allocated IP ranges.
 *   Please allocate new ranges for this service provider.
 *
 * Googleは /16 を推奨している。ここでは /20 にしている。
 *          ↕ VPCピアリング
 *   Googleが管理するVPC
 *
 * AWSではRDSやElastiCacheが自分のVPCのサブネットに直接ENIを作っていたので、
 * この手順は存在しなかった。代わりにサブネットグループを作っていた。
 *
 * ★ 1つ作れば Cloud SQL と Memorystore の両方で使い回せる
 *
 * https://cloud.google.com/vpc/docs/configure-private-services-access
 */

variable "private_service_cidr" {}

/**
 * Googleに貸し出すIPレンジを予約する
 *
 * purpose = "VPC_PEERING" が限定公開サービスアクセス用の予約という意味。
 * 第3回で使った google_compute_global_address(ロードバランサのIP)と
 * 同じリソースだが、purposeが違うと全く別の用途になる。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address
 */
resource "google_compute_global_address" "private_service" {
  name          = "${var.user_name}-private-service-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", var.private_service_cidr)[0]
  prefix_length = tonumber(split("/", var.private_service_cidr)[1])
  network       = google_compute_network.vpc.id
}

/**
 * VPCピアリングを張る
 *
 * servicenetworking.googleapis.com が Google側のサービス。
 * 上で予約したレンジを渡して接続する。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection
 */
resource "google_service_networking_connection" "private_service" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service.name]
}

/**
 * 第4回: Memorystore
 */
/**
 * Memorystore for Redis
 *
 * AWSのElastiCacheに相当する。
 *
 * ★ AWSとの違い ★
 * ElastiCacheでは以下の4つを作る必要があった。
 *   サブネットグループ / パラメータグループ /
 *   セキュリティグループ / レプリケーショングループ
 *
 * Memorystoreはインスタンス1つで済む。
 *   サブネットグループ   → 不要(限定公開サービスアクセスで接続)
 *   パラメータグループ   → redis_configs で直接指定
 *   セキュリティグループ → 不要(ピアリング経由なのでFirewall Rulesも要らない)
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance
 */
resource "google_redis_instance" "cache" {
  name           = "${var.user_name}-cache"
  region         = "asia-northeast1"
  memory_size_gb = 1

  // BASIC       : 1ノード。フェイルオーバーなし
  // STANDARD_HA : プライマリ + レプリカ。自動フェイルオーバーあり
  tier = "STANDARD_HA"

  redis_version = "REDIS_7_2"

  // 限定公開サービスアクセスで接続する
  authorized_network = google_compute_network.vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  // AWSのパラメータグループに相当
  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }

  // ピアリングが張られてから作る
  depends_on = [google_service_networking_connection.private_service]
}


/**
 * 第4回: Spanner
 */
/**
 * Cloud Spanner
 *
 * Googleが自社サービス(広告、Gmailなど)のために作ったデータベース。
 * リレーショナルなのに、水平にスケールし、グローバルで強整合性を保つ。
 *
 * ★ AWSに相当するサービスが存在しない ★
 * DynamoDBは水平スケールするがKVSでトランザクションが限定的。
 * Auroraはリレーショナルだが1リージョンに閉じる。
 * その両方を満たすのがSpanner。
 *
 * ★ 接続方法が Cloud SQL / Memorystore と全く違う ★
 * IPアドレスもポートも持たない。Google の API を叩いて使う。
 *   → 限定公開サービスアクセス(VPCピアリング)が不要
 *   → 第2回で有効化した Private Google Access だけで届く
 *   → 認証はIAM。パスワードが存在しない
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/spanner_instance
 */
resource "google_spanner_instance" "main" {
  name         = "${var.user_name}-spanner"
  display_name = "${var.user_name} spanner"

  // インスタンス構成。どこにデータを置くかを決める
  //   regional-asia-northeast1  東京の3ゾーンに複製
  //   nam-eur-asia1             北米・欧州・アジアに複製(マルチリージョン)
  config = "regional-asia-northeast1"

  // 処理能力。1000 PU = 1ノード
  // 最小は 100 PU。勉強会では最小構成にする
  processing_units = 100

  // 勉強会用: destroy できるようにする
  // 本番では true にすること
  force_destroy = true
}

/**
 * Spanner データベース
 *
 * ★ テーブル定義(DDL)を Terraform で管理する ★
 * Cloud SQL では手でCREATE TABLEを流したが、
 * Spanner は ddl 引数でスキーマをコード管理できる。
 *
 * ★ 主キーの設計がとても重要 ★
 * Spannerはデータを主キーの順にソートして分割(スプリット)する。
 * 連番やタイムスタンプを先頭にすると書き込みが1箇所に集中する
 * (ホットスポット)。UUIDのようにばらける値を使う。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/spanner_database
 */
resource "google_spanner_database" "app" {
  instance = google_spanner_instance.main.name
  name     = "test-db"

  // GoogleSQL方言(既定)。PostgreSQL方言も選べる
  database_dialect = "GOOGLE_STANDARD_SQL"

  ddl = [
    <<-SQL
      CREATE TABLE users (
        user_id STRING(36) NOT NULL,
        name    STRING(255) NOT NULL,
        created TIMESTAMP OPTIONS (allow_commit_timestamp = true)
      ) PRIMARY KEY (user_id)
    SQL
    ,
    // インターリーブ: 親テーブルの近くに子テーブルの行を物理配置する
    // usersとその注文を一緒に読むときのJOINが速くなる
    // AWSのRDBには無い概念
    <<-SQL
      CREATE TABLE orders (
        user_id  STRING(36) NOT NULL,
        order_id STRING(36) NOT NULL,
        item     STRING(255) NOT NULL
      ) PRIMARY KEY (user_id, order_id),
      INTERLEAVE IN PARENT users ON DELETE CASCADE
    SQL
  ]

  deletion_protection = false
}

/**
 * webインスタンスのサービスアカウントにSpannerへの権限を与える
 *
 * ★ パスワードが要らない ★
 * Cloud SQL では DBユーザーとパスワードを作ったが、
 * Spanner は IAM で認証する。アプリは何も持たない。
 *
 * 第1回でやった「サービスアカウントにリソース単位でロールを付ける」の実践。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/spanner_database_iam
 */
resource "google_spanner_database_iam_member" "web" {
  instance = google_spanner_instance.main.name
  database = google_spanner_database.app.name
  role     = "roles/spanner.databaseUser"
  member   = "serviceAccount:${google_service_account.web.email}"
}

/**
 * 第5回から参照するための output
 */

/**
 * 第5回: Cloud Run
 *
 * ★ Artifact Registry のリポジトリは、ここには含めていません ★
 *
 * 第5回では自分のリポジトリを作り、自分でビルドして push した。
 * 第6回はコンテナが主題ではないので、そこは再現しない。
 *
 * もし自分のリポジトリを作ってしまうと、
 * 「リポジトリを作る → イメージを push する → Cloud Run を作る」
 * の順に apply を分ける必要があり、
 * 一度の apply で前回までの状態に戻せなくなるため。
 *
 * 代わりに、講師が用意した共通リポジトリのイメージを使う。
 * 自分でビルドするところは、第7回のCI/CDでまたやります。
 */
variable "app_image_repo" {
  description = "講師が用意した共通イメージのリポジトリ名"
  default     = "infra-study-common"
}

/**
 * Cloud Run 用のサービスアカウント
 *
 * ★ AWSのECSでは2種類のロールが必要だった ★
 *   ECSタスクロール       コンテナが他サービスを使うためのロール
 *   ECSタスク実行ロール   ECRからイメージを取る / ログを出すためのロール
 *
 * Cloud Run はサービスアカウント1つで済む。
 * イメージの取得とログ出力は Cloud Run 自身が持つ権限で行われるため、
 * 「実行ロール」に相当するものが要らない。
 */
resource "google_service_account" "run" {
  account_id   = "${var.user_name}-run"
  display_name = "${var.user_name} cloud run"
}

/**
 * Spanner への権限
 *
 * 第4回でVMのサービスアカウントに付けたのと同じもの。
 * アプリの動く場所が VM から Cloud Run に変わっただけで、
 * 権限の付け方は変わらない。
 */
resource "google_spanner_database_iam_member" "run" {
  instance = google_spanner_instance.main.name
  database = google_spanner_database.app.name
  role     = "roles/spanner.databaseUser"
  member   = "serviceAccount:${google_service_account.run.email}"
}

/**
 * Cloud Run サービス
 *
 * ★ AWSのECS+Fargateとの比較 ★
 *
 *   AWS                          GCP
 *   ─────────────────────────────────────────
 *   ECSクラスター                 不要
 *   ECSタスク定義                 Cloud Runサービスに内包
 *   ECSサービス                   同上
 *   タスクロール                  サービスアカウント
 *   タスク実行ロール              不要
 *   ターゲットグループへの登録     サーバレスNEG(Step4)
 *
 *   10リソース → 3リソース
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service
 */
resource "google_cloud_run_v2_service" "app" {
  name     = "${var.user_name}-app"
  location = "asia-northeast1"

  // 誰がこのサービスを呼べるか
  //   INGRESS_TRAFFIC_ALL                   インターネットから直接
  //   INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER LBからのみ
  ingress = "INGRESS_TRAFFIC_ALL"

  deletion_protection = false

  template {
    service_account = google_service_account.run.email

    /**
     * Direct VPC egress
     *
     * ★ Cloud Run は既定ではVPCの外にいる ★
     *
     * 第4回でやった「3種類の接続方式」を思い出す。
     *   Spanner      Google API 経由   → 追加設定なしで繋がる
     *   Memorystore  VPCピアリング     → VPCの中にいないと繋がらない
     *
     * Cloud Run のインスタンスにVPC内のIPを持たせることで、
     * ピアリング経由の Memorystore に届くようになる。
     *
     * ★ 2つのやり方がある
     *   サーバレスVPCアクセスコネクタ(旧)  専用VMが立つ。課金される
     *   Direct VPC egress(新)              追加VM不要。速い。安い ← こちら
     *
     * https://cloud.google.com/run/docs/configuring/vpc-direct-vpc
     */
    vpc_access {
      network_interfaces {
        subnetwork = google_compute_subnetwork.private.id
      }
      // PRIVATE_RANGES_ONLY : プライベートIP宛だけVPCへ流す
      // ALL_TRAFFIC         : 全ての外向き通信をVPCへ流す(Cloud NAT経由になる)
      egress = "PRIVATE_RANGES_ONLY"
    }

    // スケールの範囲
    // AWSのECSサービスの desired_count に相当するが、
    // Cloud Runはリクエストに応じて自動で増減する
    scaling {
      min_instance_count = 0 // 0にするとリクエストが無い間は課金されない
      max_instance_count = 3
    }

    containers {
      // 講師が用意した共通リポジトリのイメージ(第5回で push したものと同じ中身)
      image = "asia-northeast1-docker.pkg.dev/${var.project_id}/${var.app_image_repo}/app"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }

      // 設定は環境変数で渡す(第4回で環境変数化しておいた)
      env {
        name  = "DB_KIND"
        value = "spanner"
      }
      env {
        name  = "SPANNER_DATABASE"
        value = "projects/${var.project_id}/instances/${google_spanner_instance.main.name}/databases/${google_spanner_database.app.name}"
      }
      env {
        name  = "CACHE_HOST"
        value = google_redis_instance.cache.host
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  /**
   * ★★ 第7回で足したもの ★★
   *
   * 第7回から、動かすイメージを決めるのは Terraform ではなく CI/CD になった。
   * Cloud Build が `gcloud run deploy` でイメージを差し替えるため、
   * Terraform が知っている image と実物がズレる。
   *
   * ignore_changes を書いておかないと、次に terraform apply したときに
   * 「image が変わっている」と判断して、古いイメージに巻き戻してしまう。
   *
   * これは実務で必ずぶつかるところ。
   * **インフラの形は Terraform、動かすバージョンは CI/CD** という
   * 責務の分け方を、この1ブロックで表現している。
   */
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

/**
 * 認証なしでアクセスできるようにする
 *
 * Cloud Run は既定で「呼び出しにIAM認証が必要」になっている。
 * Webサイトとして公開するには allUsers に invoker を与える。
 *
 * ★ 第1回 S25 で「allUsers は事故の元」と言ったやつ
 *   ここでは意図的に公開するので正しい使い方
 */
resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.app.name
  location = google_cloud_run_v2_service.app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}


/**
 * 第5回: サーバレスNEG
 */
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
 * 第6回: storage
 */
/**
 * Cloud Storage バケット
 *
 * AWSのS3に相当する。
 *
 * ★ S3との違い ★
 *   S3   バケットはリージョンに属する
 *   GCS  location で リージョン / デュアルリージョン / マルチリージョン を選ぶ
 *
 *   S3   ACLとバケットポリシーの2系統があり、どちらが効くか分かりにくかった
 *   GCS  均一なバケットレベルのアクセス(UBLA)でIAMに一本化できる
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
 */
resource "google_storage_bucket" "static" {
  name     = "${var.project_id}-static-${var.user_name}"
  location = "ASIA-NORTHEAST1"

  // ストレージクラス
  //   STANDARD  頻繁にアクセスする(既定)
  //   NEARLINE  月1回程度      最低保存30日
  //   COLDLINE  四半期に1回程度 最低保存90日
  //   ARCHIVE   年1回程度      最低保存365日
  storage_class = "STANDARD"

  // 旧来のACLを無効化し、権限管理をIAMに一本化する
  // 第1回のtfstateバケットでも同じ設定をしている
  uniform_bucket_level_access = true

  // 勉強会用: 中身が残っていても destroy できるようにする
  // ★ AWS版では「S3の中身は手動で削除してください」という注意があった
  //   GCPは force_destroy = true で自動的に消せる
  force_destroy = true
}

/**
 * 静的ファイルをアップロードする
 *
 * ★ Terraformでファイルを配置できる ★
 * AWS版では `aws s3 sync` を手で叩いていたが、
 * google_storage_bucket_object でコード管理できる。
 *
 * 大量のファイルには向かない(1ファイル1リソースになる)ので、
 * 実務ではCI/CDから gcloud storage rsync することが多い。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
 */
resource "google_storage_bucket_object" "index" {
  // ★ オブジェクト名が、そのままURLのパスになる ★
  // バックエンドバケットは /static/index.html のリクエストを
  // オブジェクト "static/index.html" として取りに行く。
  // URLマップの path_rule で振り分けるパスと、
  // オブジェクト名の階層を合わせておくこと。
  name   = "static/index.html"
  bucket = google_storage_bucket.static.name
  source = "${path.module}/static/index.html"

  content_type = "text/html"

  // ★ キャッシュ制御 ★
  // Cloud CDN はこのヘッダを見てキャッシュの寿命を決める
  //   public       CDNにキャッシュしてよい
  //   max-age      ブラウザのキャッシュ時間(秒)
  //   s-maxage     CDNのキャッシュ時間(秒)
  cache_control = "public, max-age=60, s-maxage=300"
}

resource "google_storage_bucket_object" "style" {
  name          = "static/style.css"
  bucket        = google_storage_bucket.static.name
  source        = "${path.module}/static/style.css"
  content_type  = "text/css"
  cache_control = "public, max-age=60, s-maxage=300"
}

/**
 * 第6回: cdn
 */
/**
 * バックエンドバケット + Cloud CDN
 *
 * ★ AWSとの一番大きな違い ★
 *
 * CloudFront は独立したサービスで、ディストリビューションを作り、
 * オリジン・キャッシュ動作・証明書・ドメインを全部その中に設定していた。
 *
 * Cloud CDN は独立したサービスではなく、
 * **ロードバランサのバックエンドに付ける機能**。
 * `enable_cdn = true` を書くだけで有効になる。
 *
 *   AWS  [Route53] → [CloudFront] → [S3]
 *                     独立したサービス
 *
 *   GCP  [Cloud DNS] → [ロードバランサ] → [バックエンドバケット] → [GCS]
 *                        第3回で作ったもの      enable_cdn = true
 *
 * つまり第3回で作ったロードバランサに、配信先を1つ足すだけ。
 * ドメインも証明書もそのまま使える。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_bucket
 */
resource "google_compute_backend_bucket" "static" {
  name        = "${var.user_name}-static-bb"
  bucket_name = google_storage_bucket.static.name

  // これだけでCDNが有効になる
  enable_cdn = true

  cdn_policy {
    // キャッシュの判断方法
    //   CACHE_ALL_STATIC    静的コンテンツを自動でキャッシュ(既定)
    //   USE_ORIGIN_HEADERS  オリジンのCache-Controlに従う
    //   FORCE_CACHE_ALL     全部キャッシュ(Cache-Controlを無視)
    //
    // 既定のままだと Cache-Control が無くてもキャッシュされてしまい、
    // 「なぜキャッシュされているか」がコードから読めない。
    // オブジェクトに付けた Cache-Control で寿命を決めたいので明示する。
    cache_mode = "USE_ORIGIN_HEADERS"

    // オリジンが落ちている間、期限切れのキャッシュを返し続ける秒数
    serve_while_stale = 86400

    // 同じURLへの同時リクエストをまとめてオリジンに1回だけ問い合わせる
    // (キャッシュミス時にオリジンへ殺到するのを防ぐ)
    request_coalescing = true
  }
}

/**
 * 第6回: lb
 */
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

/**
 * 第6回: public
 */
/**
 * バケットを公開する
 *
 * ★ AWS版の「Access Denied → バケットポリシー」と同じ場面 ★
 *
 * AWSでは CloudFront の OAI(オリジンアクセスアイデンティティ)を作り、
 * その principal に GetObject を許可するバケットポリシーを書いた。
 *
 * GCPのバックエンドバケットには OAI に相当する仕組みが無い。
 * Cloud CDN は「公開されたオブジェクト」を読みに行くので、
 * allUsers に閲覧権限を与える必要がある。
 *
 * ★ 第1回 S25 で「allUsers は事故の元」と言ったやつ ★
 * ここでは意図的に公開するので正しい使い方。
 * ただし「バケット全体が誰でも直接読める」状態になる点は理解しておくこと。
 *   → CDN経由でなくても https://storage.googleapis.com/<バケット>/<オブジェクト>
 *     で読めてしまう
 *
 * ★ 非公開のまま配信したい場合 ★
 *   署名付きURL / 署名付きCookie を使う
 *   Cloud CDN の署名付きリクエスト機能を使う
 *   → 宿題で扱います
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam
 */
resource "google_storage_bucket_iam_member" "public" {
  bucket = google_storage_bucket.static.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

/**
 * 第7回から参照するための output
 */
output "vpc_id" { value = google_compute_network.vpc.id }
output "vpc_name" { value = google_compute_network.vpc.name }
output "private_subnet_id" { value = google_compute_subnetwork.private.id }
output "cloud_run_name" { value = google_cloud_run_v2_service.app.name }
output "web_domain" {
  value = "${var.user_name}.${trimsuffix(data.google_dns_managed_zone.public.dns_name, ".")}"
}
output "cloud_run_location" { value = google_cloud_run_v2_service.app.location }
output "cloud_run_sa_email" { value = google_service_account.run.email }
output "cloud_run_sa_id" { value = google_service_account.run.id }
output "cloud_run_id" { value = google_cloud_run_v2_service.app.id }
output "spanner_instance" { value = google_spanner_instance.main.name }
output "spanner_database" { value = google_spanner_database.app.name }
output "bucket_name" { value = google_storage_bucket.static.name }
output "web_https_url" {
  value = "https://${var.user_name}.${trimsuffix(data.google_dns_managed_zone.public.dns_name, ".")}"
}
output "dns_name" { value = data.google_dns_managed_zone.public.dns_name }
