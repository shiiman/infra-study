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
  member   = "serviceAccount:${module.before.web_service_account_email}"
}

output "spanner_database" {
  value = "projects/${var.project_id}/instances/${google_spanner_instance.main.name}/databases/${google_spanner_database.app.name}"
}
