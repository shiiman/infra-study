/**
 * Uptime check(外形監視)
 *
 * ★ 「外から見て生きているか」を確かめる ★
 *
 * Cloud Run のメトリクスは「リクエストが来たときに何が起きたか」しか分からない。
 * リクエストが1件も来ていないとき、それが
 *   「誰も使っていないだけ」なのか
 *   「そもそも繋がらない」のか
 * は区別できない。
 *
 * Uptime check は Google が世界の複数拠点から定期的に叩いてくれるので、
 * **誰も使っていない時間帯でも壊れていることに気づける**。
 *
 * ★ AWSとの対応 ★
 *   Route 53 ヘルスチェック / CloudWatch Synthetics に相当する。
 *
 * ★★ 200が返ることは「生きている」証拠にならない ★★
 *
 * 「存在しないパスを叩けば失敗するだろう」と思うところだが、
 * このアプリは Go の http.HandleFunc("/", handler) で書かれていて、
 * **どんなパスでも 200 を返す**。
 *
 *   curl https://<自分の名前>.<ドメイン>/this-path-does-not-exist
 *   → 200
 *
 * ステータスコードだけを見る監視では、
 * 「エラーページを200で返すアプリ」も「常に200を返すアプリ」も正常に見える。
 *
 * ★ そこで中身も見る ★
 *
 * content_matchers を使うと、レスポンス本文に
 * 期待する文字列が含まれているかまで確かめられる。
 *
 * 今日はわざと**存在しない文字列**を指定して、失敗する状態を作る。
 * Step3 でアラートを繋いだあと、正しい文字列に直す。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_uptime_check_config
 */
resource "google_monitoring_uptime_check_config" "web" {
  display_name = "${var.user_name}-uptime"

  // 何秒ごとに叩くか。60s / 300s / 600s / 900s から選ぶ
  period = "60s"

  // 応答がこの時間内に返らなければ失敗
  timeout = "10s"

  http_check {
    path         = "/"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  /**
   * 本文に期待する文字列
   *
   * ★ わざと存在しない文字列を指定しています ★
   * Step3 の最後に "DB接続" へ直します。
   *
   * matcher に指定できるもの
   *   CONTAINS_STRING       含まれていれば成功(既定)
   *   NOT_CONTAINS_STRING   含まれていなければ成功
   *   MATCHES_REGEX         正規表現に一致すれば成功
   *   MATCHES_JSON_PATH     JSONの特定の値を見る(APIの監視向け)
   *
   * ★ 何を指定するか ★
   * 「そのページが正しく作られたときにだけ出る文字列」を選ぶ。
   * 固定のヘッダやフッタは、DBが落ちていても出てしまうので意味がない。
   *
   * このアプリなら「DB接続」の行は
   * **DBに問い合わせた結果**なので、健全性の証拠になる。
   */
  content_matchers {
    content = "ALL SYSTEMS NORMAL"
    matcher = "CONTAINS_STRING"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = module.before.web_domain
    }
  }

  /**
   * どこから叩くか
   *
   * 指定しないと全リージョンから叩かれる。
   * 「1拠点だけ失敗」を障害と誤認しないよう、
   * 既定では複数拠点の過半数で判定される。
   */
  selected_regions = ["ASIA_PACIFIC", "USA_OREGON", "EUROPE"]
}

/**
 * ダッシュボード
 *
 * ★ JSON で書く ★
 *
 * Terraform のリソースとしては dashboard_json に文字列を渡すだけ。
 * 中身は Cloud Monitoring のダッシュボード定義そのもの。
 *
 * ★ 実務での作り方 ★
 * 一から JSON を書く人はいない。
 *   1. コンソールで画面を作る
 *   2. 「JSON エディタ」でコピーする
 *   3. Terraform に貼って変数化する
 * この順番が速い。
 *
 * ★ 何を並べるか ★
 * 「まず見るもの」を左上から並べる。今回は4つ。
 *
 *   1. Uptime check の成否   → 外から生きているか
 *   2. リクエスト数           → どれだけ来ているか
 *   3. レイテンシ(95パーセンタイル) → 遅くなっていないか
 *   4. アプリのエラー数(ログベース指標) → 中で失敗していないか
 *
 * 1〜3が「外から見た様子」、4が「中の様子」。
 * この2種類を並べておくと、障害のとき切り分けが速い。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_dashboard
 */
resource "google_monitoring_dashboard" "app" {
  dashboard_json = jsonencode({
    displayName = "${var.user_name} インフラ勉強会"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "外形監視(失敗していないか)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\"",
                      "resource.type=\"uptime_url\"",
                      "metric.labels.check_id=\"${google_monitoring_uptime_check_config.web.uptime_check_id}\"",
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_FRACTION_TRUE"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "リクエスト数"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"run.googleapis.com/request_count\"",
                      "resource.type=\"cloud_run_revision\"",
                      "resource.labels.service_name=\"${module.before.cloud_run_name}\"",
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      // レスポンスコードのクラス別に色分けする
                      groupByFields = ["metric.labels.response_code_class"]
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        },
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "レイテンシ(95パーセンタイル)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"run.googleapis.com/request_latencies\"",
                      "resource.type=\"cloud_run_revision\"",
                      "resource.labels.service_name=\"${module.before.cloud_run_name}\"",
                    ])
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_PERCENTILE_95"
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "アプリのエラー数(ログベース指標)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"logging.googleapis.com/user/${google_logging_metric.app_error.name}\"",
                      "resource.type=\"cloud_run_revision\"",
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        },
      ]
    }
  })
}

output "uptime_check_id" {
  value = google_monitoring_uptime_check_config.web.uptime_check_id
}
