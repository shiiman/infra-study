/**
 * Cloud SQL for MySQL
 *
 * AWSのRDS / Auroraに相当する。
 *
 * ★ AWSとの違い ★
 * RDSでは以下を作っていた。
 *   サブネットグループ / パラメータグループ /
 *   クラスターパラメータグループ / セキュリティグループ /
 *   RDSクラスター / RDSクラスターインスタンス
 *
 * Cloud SQLはインスタンス1つ + データベース + ユーザーで済む。
 *   サブネットグループ   → 不要(限定公開サービスアクセスで接続)
 *   パラメータグループ   → database_flags で直接指定
 *   セキュリティグループ → 不要
 *   クラスター/インスタンスの2階層 → 1つにまとまっている
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance
 */
resource "google_sql_database_instance" "db" {
  name             = "${var.user_name}-db"
  database_version = "MYSQL_8_0"
  region           = "asia-northeast1"

  settings {
    // db-f1-micro は共有CPU。本番では db-custom-2-7680 のように指定する
    tier = "db-g1-small"

    // ZONAL    : 1ゾーン。フェイルオーバーなし
    // REGIONAL : 別ゾーンにスタンバイを持ち、自動フェイルオーバーする
    availability_type = "REGIONAL"

    disk_size = 10
    disk_type = "PD_SSD"

    ip_configuration {
      // パブリックIPを持たせない。VPC内からのみ接続する
      ipv4_enabled                                  = false
      private_network                               = module.before.vpc_id
      enable_private_path_for_google_cloud_services = true
    }

    // AWSのパラメータグループに相当
    database_flags {
      name  = "character_set_server"
      value = "utf8mb4"
    }

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
      start_time         = "18:00" // UTC。JSTの午前3時
    }
  }

  // 勉強会用: destroy できるようにする
  // 本番では true にして誤削除を防ぐこと
  deletion_protection = false

  depends_on = [google_service_networking_connection.private_service]
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
  host     = "%"

  // password ではなく password_wo を使う(tfstateに残らない)
  password_wo         = var.db_password
  password_wo_version = 1

  lifecycle {
    // 渡し忘れると host="%" のパスワード無しユーザーができてしまうので、apply の前に止める
    // (Secret Manager と違い、Cloud SQL は空のパスワードを受け付ける)
    // destroy のときは評価されないので、値なしで消せる
    precondition {
      condition     = var.db_password != ""
      error_message = "db_password が空です。TF_VAR_db_password を設定してから apply してください。"
    }
  }
}

output "db_host" {
  value = google_sql_database_instance.db.private_ip_address
}

output "db_connection_name" {
  value = google_sql_database_instance.db.connection_name
}
