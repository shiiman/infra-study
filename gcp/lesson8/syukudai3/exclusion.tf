/**
 * 宿題3: ログのコストを下げる
 *
 * ★ ログは黙っていると高くつく ★
 *
 * Cloud Logging は「取り込んだ量」で課金される。
 * 月50GiBまでは無料だが、それを超えると $0.50/GiB ほどかかる。
 *
 * アクセスログは1リクエスト1行出る。
 * 秒間100リクエストなら1日に約860万行。
 * **何もしないと、監視のためのログが一番高い費用になる**ことがある。
 *
 * ★ 減らし方は2つ ★
 *
 *   除外(exclusion)  そもそも取り込まない。一番効く
 *   シンク + 除外     長期保存には流しつつ、Loggingからは除く
 *
 * ★ 消してよいログの見分け方 ★
 *
 * 「障害のときに見るか」で決める。
 *   ヘルスチェックの200      → 見ない。除外してよい
 *   Uptime check の200       → 見ない。除外してよい
 *   アプリのエラー           → 見る。絶対に残す
 *   監査ログ                 → 見る。というより法令で残す義務がある場合も
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_exclusion
 */
resource "google_logging_project_exclusion" "healthcheck" {
  name        = "${var.user_name}-exclude-healthcheck"
  description = "ヘルスチェックと外形監視の成功ログを取り込まない"

  /**
   * ★ 除外は「取り込まない」設定 ★
   *
   * 一度除外すると、あとから「やっぱり見たい」と思っても戻せない。
   * シンクで別の場所に流してから除外する、という順にすると安全。
   *
   * ★ ロードバランサのヘルスチェックの見分け方 ★
   * User-Agent が GoogleHC/ になっている。
   */
  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${module.before.cloud_run_name}"
    httpRequest.status=200
    (
      httpRequest.userAgent:"GoogleHC"
      OR httpRequest.userAgent:"GoogleStackdriverMonitoring"
    )
  EOT
}

/**
 * ログバケットの保持期間を短くする
 *
 * ★ 保持期間でも課金が変わる ★
 *
 * 既定の _Default バケットは30日保持で、そこまでは追加費用なし。
 * 30日を超える保持には保存料金がかかる。
 *
 * 逆に**短くしても取り込み料金は減らない**。
 * 取り込み量を減らしたいなら、上の除外を使う。
 *
 * ここでは「自分専用のログバケットを作って7日で消す」を試す。
 * 用途ごとにバケットを分けると、保持期間を使い分けられる。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_bucket_config
 */
resource "google_logging_project_bucket_config" "short" {
  project        = var.project_id
  location       = "asia-northeast1"
  bucket_id      = "${var.user_name}-shortterm"
  retention_days = 7
  description    = "短期保持用。7日で消える"
}
