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
      image = "debian-cloud/debian-13"

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
 * <自分の名前>.infra-study-gcp.sumsp.jp を
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
 * 作成したリソースを確認するための output
 */

/**
 * 作成したリソースを確認するための output
 */

/**
 * 第4回: Private Service Connect
 */
/**
 * Private Service Connect (PSC) とサービス接続ポリシー
 *
 * ★ AWSには無い、GCP独自の前提 ★
 *
 * Memorystore や Cloud SQL は「Googleが管理するVPC」の中で動いている。
 * 自分のVPCとは別のネットワークなので、そのままでは繋がらない。
 *
 * PSC は、自分のVPCの中に「エンドポイント」(内部IPを1つ)を立てて、
 * そのIPに向かって接続すると、Google側のサービスに届く仕組み。
 *
 *   自分のVPC 172.16.0.0/16
 *     ├ public  172.16.0.0/24
 *     └ private 172.16.10.0/24
 *         └ 172.16.10.4  ← エンドポイント。このIP宛に接続する
 *                ↕ PSC
 *   Googleが管理するVPC(Memorystore がいる)
 *
 * 貸し出すのはIP 1つ分だけで、IPレンジの設計は要らない。
 * (限定公開サービスアクセスは、IPレンジを丸ごとGoogleに貸し出してピアリングを張っていた)
 *
 * AWSではRDSやElastiCacheが自分のVPCのサブネットに直接ENIを作っていたので、
 * この手順は存在しなかった。代わりにサブネットグループを作っていた。
 *
 * ★ サービス接続ポリシー ★
 * 「このVPCの、このサブネットに、この種類のサービスのエンドポイントを
 *  自動で作ってよい」という許可。サービスの種類(サービスクラス)ごとに1つ作る。
 *
 *   Memorystore → gcp-memorystore
 *   Cloud SQL   → google-cloud-sql
 *
 * ポリシーがあると、インスタンスを作るときにエンドポイントが自動で作られる。
 * エンドポイントのIPは、subnetworks に指定したサブネットから払い出される。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_service_connection_policy
 */
resource "google_network_connectivity_service_connection_policy" "memorystore" {
  name          = "${var.user_name}-memorystore"
  location      = "asia-northeast1"
  service_class = "gcp-memorystore"
  network       = google_compute_network.vpc.id

  psc_config {
    // エンドポイントのIPを払い出すサブネット
    subnetworks = [google_compute_subnetwork.private.id]
  }
}

/**
 * 第4回: Memorystore
 */
/**
 * Memorystore for Valkey
 *
 * AWSのElastiCache(Valkey)に相当する。
 * ValkeyはRedisから派生したオープンソースで、Redisと同じ方法で接続できる。
 *
 * ★ Redis ではなく Valkey を使う理由 ★
 * Memorystore for Redis(クラスタ無しの標準版)の接続方式は、
 * 限定公開サービスアクセスかダイレクトピアリングの2つで、PSCは選べない。
 * PSCで繋げるのは、Memorystore for Valkey と Memorystore for Redis Cluster。
 * Valkey は PSC でしか繋げない(限定公開サービスアクセスは選べない)。
 *
 * ★ AWSとの違い ★
 * ElastiCacheでは以下の4つを作る必要があった。
 *   サブネットグループ / パラメータグループ /
 *   セキュリティグループ / レプリケーショングループ
 *
 * Memorystoreはインスタンス1つで済む。
 *   サブネットグループ   → 不要(PSCのエンドポイントが自動で作られる)
 *   パラメータグループ   → engine_configs で直接指定
 *   セキュリティグループ → 不要(エンドポイント宛の通信になるのでFirewall Rulesも要らない)
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/memorystore_instance
 */
resource "google_memorystore_instance" "cache" {
  instance_id = "${var.user_name}-cache"
  location    = "asia-northeast1"

  // CLUSTER_DISABLED : シャードは1つ。Redis と同じ使い方になる
  // CLUSTER          : データを複数のシャードに分散する(クラスタ対応のクライアントが要る)
  mode        = "CLUSTER_DISABLED"
  shard_count = 1

  // プライマリに付けるレプリカの数
  // 0      : 1ノード。フェイルオーバーなし
  // 1以上  : プライマリ + レプリカ。自動フェイルオーバーあり
  replica_count = 0

  // 勉強会用の最小サイズ(共有CPU)
  node_type      = "SHARED_CORE_NANO"
  engine_version = "VALKEY_9_1"

  // 勉強会用: 通信の暗号化と認証を切る
  // 本番では transit_encryption_mode = SERVER_AUTHENTICATION と authorization_mode = IAM_AUTH を使うこと
  transit_encryption_mode = "TRANSIT_ENCRYPTION_DISABLED"
  authorization_mode      = "AUTH_DISABLED"

  // AWSのパラメータグループに相当
  engine_configs = {
    maxmemory-policy = "allkeys-lru"
  }

  // PSCのエンドポイントを、自分のVPCの中に自動で作る
  desired_auto_created_endpoints {
    network    = google_compute_network.vpc.id
    project_id = var.project_id
  }

  // 勉強会用: destroy できるようにする
  // 本番では true にして誤削除を防ぐこと
  deletion_protection_enabled = false

  // ポリシーが先にないと、エンドポイントを作れずに失敗する
  depends_on = [google_network_connectivity_service_connection_policy.memorystore]
}

/**
 * 自動で作られたエンドポイントのIP
 *
 * エンドポイントは、プライマリ(読み書き)と、レプリカがあるときのリーダー(読み取り専用)の
 * 2種類。connection_type で見分けて、プライマリのIPをアプリに渡す。
 */
locals {
  cache_connections = flatten([
    for e in google_memorystore_instance.cache.endpoints : [
      for c in e.connections : c.psc_auto_connection[0]
    ]
  ])
  cache_host = [
    for c in local.cache_connections : c.ip_address
    if c.connection_type == "CONNECTION_TYPE_PRIMARY"
  ][0]
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
 * 作成したリソースを確認するための output
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
variable "before_app_image_repo" {
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
  // Step4でLB経由にするまでは、動作確認のため直接アクセスできるようにする
  ingress = "INGRESS_TRAFFIC_ALL"

  deletion_protection = false

  template {
    service_account = google_service_account.run.email

    /**
     * Direct VPC egress
     *
     * ★ Cloud Run は既定ではVPCの外にいる ★
     *
     * 第4回でやった「4種類の接続方式」を思い出す。
     *   Spanner      Google API 経由   → 追加設定なしで繋がる
     *   Memorystore  PSC               → VPCの中にいないと繋がらない
     *
     * Cloud Run のインスタンスにVPC内のIPを持たせることで、
     * VPC内にある PSC のエンドポイントに届くようになる。
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
      image = "asia-northeast1-docker.pkg.dev/${var.project_id}/${var.before_app_image_repo}/app"

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
        name  = "SPANNER_DATABASE"
        value = "projects/${var.project_id}/instances/${google_spanner_instance.main.name}/databases/${google_spanner_database.app.name}"
      }
      env {
        name  = "CACHE_HOST"
        value = local.cache_host
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
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

/**
 * 第6回から参照するための output
 */
output "vpc_id" { value = google_compute_network.vpc.id }
output "vpc_name" { value = google_compute_network.vpc.name }
output "private_subnet_id" { value = google_compute_subnetwork.private.id }
output "global_address_id" { value = google_compute_global_address.web.id }
output "ssl_certificate_id" { value = google_compute_managed_ssl_certificate.web.id }
output "run_backend_service_id" { value = google_compute_backend_service.run.id }
output "cloud_run_url" { value = google_cloud_run_v2_service.app.uri }
output "web_https_url" {
  value = "https://${var.user_name}.${trimsuffix(data.google_dns_managed_zone.public.dns_name, ".")}"
}
output "dns_name" { value = data.google_dns_managed_zone.public.dns_name }
