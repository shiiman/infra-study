/**
 * Cloud SQL 用のサービス接続ポリシー
 *
 * Memorystore で作ったポリシー(private_service_connect.tf)とは別に、
 * Cloud SQL のサービスクラス google-cloud-sql 用のポリシーが要る。
 * ポリシーは、ネットワーク・リージョン・サービスクラスごとに1つ作る。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_service_connection_policy
 */
resource "google_network_connectivity_service_connection_policy" "sql" {
  name          = "${var.user_name}-sql"
  location      = "asia-northeast1"
  service_class = "google-cloud-sql"
  network       = google_compute_network.vpc.id

  psc_config {
    subnetworks = [google_compute_subnetwork.private.id]
  }
}

/**
 * Cloud SQL for PostgreSQL
 *
 * Terraform で作るのは、インスタンス1つ + データベース + ユーザーの3リソース。
 *   サブネットグループ   → 不要(PSCのエンドポイントが自動で作られる)
 *   パラメータグループ   → 必要なときは database_flags で直接指定
 *   セキュリティグループ → 不要(エンドポイント宛の通信になるのでFirewall Rulesも要らない)
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance
 */
resource "google_sql_database_instance" "db" {
  name             = "${var.user_name}-db"
  database_version = "POSTGRES_18"
  region           = "asia-northeast1"

  settings {
    // PostgreSQL 17 以降の既定は Enterprise Plus。勉強会では Enterprise を使う
    edition = "ENTERPRISE"

    // 共有CPU(db-g1-small など)は HA にできないので、専用の 1vCPU を使う
    // 本番では db-custom-2-7680 のように、負荷に合わせて指定する
    tier = "db-custom-1-3840"

    // ZONAL    : 1ゾーン。フェイルオーバーなし
    // REGIONAL : 別ゾーンにスタンバイを持ち、自動フェイルオーバーする(HA)
    availability_type = "REGIONAL"

    disk_size = 10
    disk_type = "PD_SSD"

    ip_configuration {
      // パブリックIPを持たせない。VPC内からのみ接続する
      ipv4_enabled = false

      // PSCで接続する。自分のVPCの中にエンドポイントが自動で作られる
      psc_config {
        psc_enabled = true

        // このプロジェクトからの接続だけを許可する
        allowed_consumer_projects = [var.project_id]

        // エンドポイントを作るVPC。ポリシーがあるので自動で作られる
        psc_auto_connections {
          consumer_network            = google_compute_network.vpc.id
          consumer_service_project_id = var.project_id
        }
      }
    }

    backup_configuration {
      enabled = true

      // PostgreSQL の HA には、ポイントインタイムリカバリ(WALの保管)が要る
      point_in_time_recovery_enabled = true

      start_time = "18:00" // UTC。JSTの午前3時
    }
  }

  // 勉強会用: destroy できるようにする
  // 本番では true にして誤削除を防ぐこと
  deletion_protection = false

  // ポリシーが先にないと、エンドポイントを作れずに失敗する
  depends_on = [google_network_connectivity_service_connection_policy.sql]
}

/**
 * データベース作成
 */
resource "google_sql_database" "app" {
  name     = "test_db"
  instance = google_sql_database_instance.db.name
}

/**
 * DBユーザー作成
 *
 * ★ パスワードをどう扱うか ★
 *
 * 第1回の宿題2でやったとおり、Terraformに秘密の値を書くと
 * tfstateに平文で残る。google_sql_user の password も同じ。
 *
 * ここでは password_wo(write-only 引数)を使う。
 * この引数に渡した値は tfstate に保存されない。
 *
 * 値そのものは terraform.tfvars にも書かず、
 * 環境変数 TF_VAR_db_password から渡す。
 *
 *   read -rs TF_VAR_db_password; export TF_VAR_db_password
 *   terraform apply
 *   unset TF_VAR_db_password
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user
 */
variable "db_password" {
  type      = string
  sensitive = true

  // 値を plan / state のどちらにも残さない(write-only 引数に渡せるのは ephemeral な値だけ)
  ephemeral = true

  // default が無いと terraform destroy でも値を聞かれてしまう
  // (destroy には使わない値なのに、変数の宣言があるだけで必須になる)
  // 空のまま apply されるのは下の precondition で止める
  default = ""
}

resource "google_sql_user" "app" {
  name     = "app"
  instance = google_sql_database_instance.db.name

  // password ではなく password_wo を使う(tfstateに残らない)
  password_wo         = var.db_password
  password_wo_version = 1

  lifecycle {
    // 渡し忘れるとパスワード無しのユーザーができてしまうので、apply の前に止める
    // (Cloud SQL は空のパスワードを受け付ける)
    // destroy のときは評価されないので、値なしで消せる
    precondition {
      condition     = var.db_password != ""
      error_message = "db_password が空です。TF_VAR_db_password を設定してから apply してください。"
    }
  }
}

// PSC では private_ip_address は空になる。
// 自動で作られたエンドポイントのIPは、psc_auto_connections に入っている
output "db_host" {
  value = google_sql_database_instance.db.settings[0].ip_configuration[0].psc_config[0].psc_auto_connections[0].ip_address
}

output "db_connection_name" {
  value = google_sql_database_instance.db.connection_name
}
