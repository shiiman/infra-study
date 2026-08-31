/**
 * 通知チャンネル(講師が作成済み)
 *
 * ★ Slack 連携はコードだけでは完結しません ★
 *
 * Cloud Monitoring から Slack に投げるには、
 * Slack 側で「Google Cloud Monitoring」アプリを認可して
 * **auth_token** を受け取る必要があります。
 * これはブラウザでの作業で、Terraform には書けません。
 *
 * 第7回の GitHub 連携と同じ形です。
 * 講師が1回だけ認可して通知チャンネルを作ってあるので、
 * 受講者はそれを参照するだけにしてあります。
 *
 * ★ 通知チャンネルは「宛先」でしかない ★
 *
 * アラートポリシーとは分かれていて、
 *   ポリシー   いつ鳴らすか
 *   チャンネル どこに鳴らすか
 * を別々に持ちます。
 *
 * 1つのポリシーに複数のチャンネルを付けられるので、
 * 「昼はSlack、深夜はPagerDuty」のような分け方ができます。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/monitoring_notification_channel
 */
variable "notification_channel_name" {
  description = "講師が作成した Slack 通知チャンネルの表示名"
  type        = string
}

data "google_monitoring_notification_channel" "slack" {
  display_name = var.notification_channel_name
}

/**
 * アラートポリシー: 外形監視が失敗した
 *
 * ★ 読み方 ★
 *
 *   conditions       いつ鳴らすか(複数書ける)
 *   combiner         複数条件をANDで見るかORで見るか
 *   notification_channels  どこに鳴らすか
 *
 * ★ しきい値の考え方 ★
 *
 * check_passed は「成功したら1、失敗したら0」を返す指標。
 * ALIGN_FRACTION_TRUE で「その期間に成功した割合」になる。
 *
 * 割合が 1 未満 = どこかの拠点で失敗した、ということ。
 * ただし1拠点の一時的な失敗で鳴らすとうるさいので、
 * **duration** で「その状態が続いたら」という条件を足す。
 *
 * ★ アラート設計で一番大事なこと ★
 *
 * 「鳴ったら人が何かする」ものだけをアラートにする。
 * 見ても何もしないものはダッシュボードに置けばよい。
 *
 * 鳴りっぱなしのアラートは、そのうち誰も見なくなる。
 * **本当に必要なときに気づけなくなる**ので、
 * 増やすより減らすほうが難しく、そして大事。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy
 */
resource "google_monitoring_alert_policy" "uptime" {
  display_name = "${var.user_name} 外形監視が失敗"
  combiner     = "OR"

  conditions {
    display_name = "Uptime check が失敗している"

    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\"",
        "resource.type=\"uptime_url\"",
        "metric.labels.check_id=\"${google_monitoring_uptime_check_config.web.uptime_check_id}\"",
      ])

      // 成功率が1未満(=どこかで失敗している)
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      // 5分続いたら鳴らす。一瞬の失敗では鳴らさない
      duration = "300s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_FRACTION_TRUE"
        cross_series_reducer = "REDUCE_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [data.google_monitoring_notification_channel.slack.name]

  /**
   * 通知に添える説明
   *
   * ★ ここをちゃんと書くかどうかで、対応の速さが変わる ★
   *
   * 夜中に叩き起こされた人が最初に見るのがこの文章。
   * 「何が起きたか」だけでなく
   * 「まず何を見ればいいか」を書いておく。
   *
   * ★★ Slack は Markdown を解釈しません ★★
   *
   * mime_type に text/markdown を指定しても、
   * Slack には ## や ** が文字のまま出ます。
   * (コンソールの画面では整形されます)
   *
   * 通知が届く先は Slack なので、
   * 記号を使わず、素のテキストで読めるように書くのが正解。
   * 箇条書きは「1.」「-」だけにして、見出しの装飾や強調は使わない。
   */
  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      ${var.user_name} のサイトが外から見えなくなっています。

      確認すること
      1. ブラウザで https://${module.before.web_domain}/ を開く
      2. Cloud Run のログを見る
         gcloud logging read 'resource.labels.service_name="${module.before.cloud_run_name}"' --limit=20
      3. ダッシュボード「${var.user_name} インフラ勉強会」でリクエスト数とエラー数を見る

      よくある原因
      - Cloud Run のリビジョンが起動に失敗している
      - ロードバランサのバックエンドが不健全
      - 監視対象の文字列を間違えている(今日はこれ)
    EOT
  }

  /**
   * 自動クローズまでの時間
   *
   * 既定は7日。障害が直ってもインシデントが開いたままだと
   * 次の障害で鳴らないことがあるので、短めにしておく。
   */
  alert_strategy {
    auto_close = "1800s"
  }
}

output "alert_policy_name" {
  value = google_monitoring_alert_policy.uptime.display_name
}

output "notification_channel" {
  value = data.google_monitoring_notification_channel.slack.display_name
}
