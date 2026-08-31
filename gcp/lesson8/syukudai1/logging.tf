/**
 * ログベース指標
 *
 * ★ ログから「数」を作る仕組み ★
 *
 * Cloud Logging に流れてくるログのうち、条件に合うものを数えて
 * Cloud Monitoring の指標にする。作った指標は
 * ダッシュボードにもアラートにも使える。
 *
 * ★ なぜ要るのか ★
 *
 * Cloud Run は「リクエスト数」「レイテンシ」「エラー率」を
 * 最初から指標として出してくれる。
 * だが **アプリが何をしたか** は出してくれない。
 *
 *   「DB接続に失敗した回数」
 *   「特定のエラーメッセージが出た回数」
 *   「決済が失敗した回数」
 *
 * こういうものはログにしか出ていない。
 * ログベース指標は、その穴を埋めるためにある。
 *
 * ★ AWSとの対応 ★
 *   CloudWatch Logs のメトリクスフィルタに相当する。
 *   考え方はほぼ同じ。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_metric
 */
resource "google_logging_metric" "app_error" {
  name        = "${var.user_name}-app-error"
  description = "アプリが「失敗」を含むログを出した回数"

  /**
   * どのログを数えるか
   *
   * ここに書くのは、Cloud Logging の検索窓に打つのと同じクエリ。
   * コンソールで先に検索して、ヒットすることを確かめてから
   * ここに貼るのが確実。
   *
   * 第4回・第5回のアプリは、DBやキャッシュに繋がらないと
   * 「DB接続(spanner): 失敗」というログを出す。それを数える。
   */
  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${module.before.cloud_run_name}"
    textPayload:"失敗"
  EOT

  metric_descriptor {
    metric_kind = "DELTA" // 期間あたりの増分
    value_type  = "INT64" // 件数
    unit        = "1"
  }
}

/**
 * ログルーター(シンク)
 *
 * ★ ログは黙っていると消える ★
 *
 * Cloud Logging の既定の保持期間は30日。
 * それより長く持ちたい、あるいは別の場所で分析したい場合は、
 * **シンク**を作ってログを外に流す。
 *
 * ★ 流し先の選び方 ★
 *
 *   Cloud Storage  安い。長期保存・監査ログの保管向け
 *   BigQuery       SQLで分析できる。障害の傾向を調べたいとき
 *   Pub/Sub        他システムへリアルタイムに渡したいとき
 *
 * 今回は Cloud Storage に流す。
 * 「とりあえず消えないようにしておく」が一番よくある用途。
 *
 * ★ AWSとの対応 ★
 *   CloudWatch Logs のサブスクリプションフィルタ + Kinesis Firehose で
 *   S3 に流していたのに近い。GCPはシンク1つで済む。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_sink
 */
resource "google_storage_bucket" "logs" {
  name     = "${var.project_id}-logs-${var.user_name}"
  location = "ASIA-NORTHEAST1"

  uniform_bucket_level_access = true
  force_destroy               = true

  // ログは増え続けるので、置きっぱなしにしない
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_logging_project_sink" "app_logs" {
  name        = "${var.user_name}-app-logs"
  destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"

  // 自分の Cloud Run のログだけを流す
  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${module.before.cloud_run_name}"
  EOT

  /**
   * ★ これを忘れると書き込めない ★
   *
   * シンクは専用のサービスアカウントを使ってログを書き込む。
   * true にすると、そのSAを Google が自動で用意し、
   * writer_identity に入れてくれる。
   *
   * false のままだと、既定のSAが使われて権限が足りず、
   * **エラーも出ないまま何も書き込まれない**。
   */
  unique_writer_identity = true
}

/**
 * シンクのサービスアカウントに書き込み権限を与える
 *
 * ★ ここが一番忘れられる ★
 *
 * シンクを作っただけでは書き込めない。
 * writer_identity に objectCreator を付けて、はじめて流れ出す。
 *
 * しかも**失敗しても静か**で、
 * 「シンクは作ったのにバケットが空のまま」という状態になる。
 *
 * バケット単位で付けられるので、範囲は狭く保てる。
 */
resource "google_storage_bucket_iam_member" "sink_writer" {
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.app_logs.writer_identity
}

output "log_metric_name" {
  value = google_logging_metric.app_error.name
}

output "log_bucket_name" {
  value = google_storage_bucket.logs.name
}

output "sink_writer_identity" {
  value = google_logging_project_sink.app_logs.writer_identity
}
