/**
 * 宿題2: 自分あての通知チャンネルを足す
 *
 * ★ 通知チャンネルは受講者でも作れる ★
 *
 * 講義では講師が作った Slack チャンネルを data で参照した。
 * Slack は auth_token の取得にブラウザ作業が要るため。
 *
 * メールなら **auth_token が要らない**ので、
 * 自分で作れる。まずはこれで「通知先もコードで管理する」を体験する。
 *
 * ★ 通知チャンネルを複数持つ意味 ★
 *
 *   Slack   チーム全員が気づける。流れて消える
 *   メール  個人に確実に届く。あとから探せる
 *   PagerDuty 電話が鳴る。深夜の重大障害向け
 *
 * どれか1つではなく、**重大度に応じて使い分ける**のが実務。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel
 */
variable "alert_email" {
  description = "アラートを受け取るメールアドレス"
  type        = string
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "${var.user_name} メール"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

/**
 * アラートポリシー: アプリのエラーログが増えた
 *
 * ★ 講義のアラートとの違い ★
 *
 * 講義の Uptime check は「外から見えるか」だけを見ていた。
 * サイトは200を返すのに中でDB接続に失敗している、という状態は
 * 外形監視では気づけない。
 *
 * Step1で作ったログベース指標を使うと、そこに気づける。
 *
 * ★ 通知先を2つ指定している ★
 * Slack とメールの両方に飛ぶ。
 */
resource "google_monitoring_alert_policy" "app_error" {
  display_name = "${var.user_name} アプリのエラーログが増えた"
  combiner     = "OR"

  conditions {
    display_name = "5分間に3件以上"

    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"logging.googleapis.com/user/${google_logging_metric.app_error.name}\"",
        "resource.type=\"cloud_run_revision\"",
      ])

      comparison      = "COMPARISON_GT"
      threshold_value = 3
      duration        = "0s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [
    data.google_monitoring_notification_channel.slack.name,
    google_monitoring_notification_channel.email.id,
  ]

  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      ${var.user_name} のアプリが「失敗」ログを出しています。
      外形監視は通っているのに、中で何かに失敗しています。

      確認すること
      1. どのログか見る
         gcloud logging read 'resource.labels.service_name="${module.before.cloud_run_name}" AND textPayload:"失敗"' --limit=20
      2. Spanner / Memorystore に繋がっているか
      3. 第4回でやった「3種類の接続方式」を思い出す
    EOT
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

output "email_channel" {
  value = google_monitoring_notification_channel.email.display_name
}
