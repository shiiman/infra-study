/**
 * 宿題1: SLO を定義してアラートを設定する
 *
 * ★ SLI / SLO / エラーバジェット ★
 *
 *   SLI  Service Level Indicator。「良いリクエストの割合」などの実測値
 *   SLO  Service Level Objective。「SLIをこの水準に保つ」という目標
 *   エラーバジェット  SLOの裏側。「どれだけ失敗してよいか」の残量
 *
 * 例: 「30日間で成功率99%」というSLOなら、
 *     失敗してよいのは1%。これがエラーバジェット。
 *     使い切っていなければ、多少エラーが出ても慌てなくてよい。
 *
 * ★ なぜ普通のアラートと分けるのか ★
 *
 * 「エラー率が5%を超えたら鳴らす」だと、
 * 深夜に一瞬5%を超えただけでも叩き起こされる。
 *
 * SLOで見ると
 *   「今月の失敗できる量のうち、もう半分使った」
 *   「このペースだと2日で使い切る」
 * という言い方になる。**慌てるべきかどうかが数字で分かる。**
 *
 * ★ AWSとの対応 ★
 *   CloudWatch には相当する機能がない(自分で計算する)。
 *   GCPは Cloud Monitoring に組み込みで入っている。
 *
 * https://cloud.google.com/stackdriver/docs/solutions/slo-monitoring
 */

/**
 * サービス
 *
 * SLOは「サービス」に紐づく。
 * Cloud Run は自動で検出されるので、それを参照する。
 *
 * ★ 自分で作る場合 ★
 * google_monitoring_custom_service を使うと、
 * 「複数のCloud Runをまとめて1サービス扱い」もできる。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_custom_service
 */
resource "google_monitoring_custom_service" "app" {
  service_id   = "${var.user_name}-service"
  display_name = "${var.user_name} アプリ"
}

/**
 * SLO: 可用性
 *
 * ★ 読み方 ★
 *
 *   goal                    目標。0.99 = 99%
 *   rolling_period_days     何日間で見るか
 *   good_total_ratio        「良い数 ÷ 全体数」で測る
 *
 * ★ 99% と 99.9% の違い ★
 *
 *   30日で 99%   → 7時間ちょっと落ちてよい
 *   30日で 99.9% → 43分しか落ちてよくない
 *
 * 桁が1つ増えるごとに、必要な手間と費用が跳ね上がる。
 * **「とりあえず99.99%」と言い出したら、まず止める。**
 * その水準が本当に要るのか、誰が夜中に起きるのかを先に決める。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_slo
 */
resource "google_monitoring_slo" "availability" {
  service      = google_monitoring_custom_service.app.service_id
  slo_id       = "${var.user_name}-availability"
  display_name = "${var.user_name} 可用性 99%"

  goal                = 0.99
  rolling_period_days = 30

  request_based_sli {
    good_total_ratio {
      // 「良いリクエスト」= 5xx以外
      good_service_filter = join(" AND ", [
        "metric.type=\"run.googleapis.com/request_count\"",
        "resource.type=\"cloud_run_revision\"",
        "resource.labels.service_name=\"${module.before.cloud_run_name}\"",
        "metric.labels.response_code_class!=\"5xx\"",
      ])

      // 「全リクエスト」
      total_service_filter = join(" AND ", [
        "metric.type=\"run.googleapis.com/request_count\"",
        "resource.type=\"cloud_run_revision\"",
        "resource.labels.service_name=\"${module.before.cloud_run_name}\"",
      ])
    }
  }
}

/**
 * バーンレートアラート
 *
 * ★ バーンレートとは ★
 *
 * エラーバジェットを**どれくらいの速さで使っているか**の倍率。
 *
 *   1倍  ちょうど30日で使い切るペース
 *   10倍 3日で使い切るペース
 *
 * 「エラー率が高い」ではなく「使い切るまであと何日か」で見る。
 * これなら、**本当に急ぐときだけ鳴る**。
 *
 * ★ しきい値の決め方(Google SRE本の定番) ★
 *
 *   速い燃焼  1時間で 14.4倍 → すぐ対応(ページャー)
 *   遅い燃焼  6時間で 6倍    → 翌営業日に対応(チケット)
 *
 * 今回は勉強会なので1つだけ、緩めに設定する。
 */
resource "google_monitoring_alert_policy" "slo_burn" {
  display_name = "${var.user_name} エラーバジェットの消費が速い"
  combiner     = "OR"

  conditions {
    display_name = "バーンレートが10倍を超えた"

    condition_threshold {
      filter = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"3600s\")"

      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "0s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [data.google_monitoring_notification_channel.slack.name]

  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      ${var.user_name} のエラーバジェットを速いペースで消費しています。
      このまま続くと、30日分の余裕を3日で使い切ります。

      確認すること
      1. ダッシュボードでリクエスト数の 5xx の割合を見る
      2. Error Reporting で何が起きているか見る
      3. 直前のデプロイを疑う(第7回のロールバック手順)
    EOT
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

output "slo_name" {
  value = google_monitoring_slo.availability.name
}
