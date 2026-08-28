variable "image_tag" { default = "app" }

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
  instance = module.before.spanner_instance_name
  database = module.before.spanner_database_name
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
     * 第4回でやった「3種類の接続方式」を思い出す。
     *   Spanner      Google API 経由   → 追加設定なしで繋がる
     *   Memorystore  VPCピアリング     → VPCの中にいないと繋がらない
     *
     * Cloud Run のインスタンスにVPC内のIPを持たせることで、
     * ピアリング経由の Memorystore に届くようになる。
     *
     * ★ 2つのやり方がある
     *   サーバレスVPCアクセスコネクタ(旧)  専用VMが立つ。課金される
     *   Direct VPC egress(新)              追加VM不要。速い。安い ← こちら
     *
     * https://cloud.google.com/run/docs/configuring/vpc-direct-vpc
     */
    vpc_access {
      network_interfaces {
        subnetwork = module.before.private_subnet_id
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
      // Step1で作ったArtifact Registryのイメージを指定する
      image = "${google_artifact_registry_repository.app.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}/${var.image_tag}"

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
        name  = "DB_KIND"
        value = "spanner"
      }
      env {
        name  = "SPANNER_DATABASE"
        value = module.before.spanner_database
      }
      env {
        name  = "CACHE_HOST"
        value = module.before.cache_host
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

output "cloud_run_url" {
  value = google_cloud_run_v2_service.app.uri
}
