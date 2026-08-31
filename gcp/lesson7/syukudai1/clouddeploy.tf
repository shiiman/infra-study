/**
 * 宿題1: Cloud Deploy でカナリアデプロイ
 *
 * ★ Cloud Build と Cloud Deploy の役割の違い ★
 *
 *   Cloud Build   「作る」。ビルドして、イメージを置いて、コマンドを叩く
 *   Cloud Deploy  「配る」。どの環境に、どういう順で、どの割合で出すかを管理する
 *
 * 講義では Cloud Build から `gcloud run deploy` を1回叩いただけだった。
 * これは「全部いっぺんに新しいイメージへ切り替える」デプロイ。
 * 問題があれば全ユーザが巻き込まれる。
 *
 * Cloud Deploy を挟むと、
 *   1. まず新しいリビジョンに 10% だけ流す
 *   2. 様子を見て、人が「進める」と判断したら 50%
 *   3. 最後に 100%
 * という段階的な切り替えができる。
 *
 * ★★ デプロイ先は別サービスにしています ★★
 *
 * Cloud Deploy は「サービスの定義まるごと」をマニフェストで持ちます。
 * 講義で作った <自分の名前>-app は Terraform が
 * 環境変数・Direct VPC egress・サービスアカウントまで管理しているので、
 * Cloud Deploy にそのまま当てると、それらを全部上書きしてしまいます。
 *
 * どちらが正しいということはなく、**どちらか一方に持たせる**のが原則です。
 *   Terraform に持たせる  → デプロイは image だけ差し替える(講義のやり方)
 *   Cloud Deploy に持たせる → サービス定義ごとリリースで管理する
 *
 * 宿題では、講義で作った環境を壊さないように
 * <自分の名前>-canary という別のサービスを Cloud Deploy に作らせます。
 *
 * ★ AWSとの対応 ★
 *   CodeDeploy の Blue/Green デプロイに相当する。
 *   AWS版 第8回では ECS + ALB のターゲットグループを2つ用意して
 *   リスナーを切り替えていた(コードで50行くらい)。
 *
 *   Cloud Run はリビジョンごとにトラフィック割合を持てるので、
 *   ターゲットグループもリスナーも要らない。
 *   percentages に数字を並べるだけで済む。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/clouddeploy_delivery_pipeline
 */

/**
 * Cloud Deploy の実行主体
 *
 * ★ 新しいサービスアカウントは作りません ★
 *
 * Cloud Deploy の実行SAには、プロジェクト単位の権限が2つ要ります。
 *
 *   roles/logging.logWriter      ログを書く(Step1と同じ理由)
 *   roles/clouddeploy.jobRunner  レンダリングとデプロイのジョブを動かす
 *
 * どちらもプロジェクト単位でしか付けられず、
 * 共有プロジェクトでは受講者が付けられません。
 * 講師が用意した <自分の名前>-build に両方付いているので、
 * それをそのまま使います。
 *
 * 実務でも「CI用のSAを1つにまとめるか、工程ごとに分けるか」は
 * よく議論になるところです。
 *   まとめる  管理が楽。ただし権限が積み上がっていく
 *   分ける    権限が絞れる。ただしSAと権限付与が増える
 */

/**
 * ★★ カナリア用のサービスは Terraform で先に作る ★★
 *
 * 「Cloud Deploy に新規作成させればいいのでは」と思うところだが、
 * それをやろうとすると **プロジェクト単位の roles/run.developer** が要る。
 *
 *   error checking Cloud Run State: Error 403:
 *   Permission 'run.services.get' denied on resource
 *   'namespaces/[プロジェクトID]/services/[自分の名前]-canary'
 *
 * サービス単位のIAMは「すでにあるサービス」にしか付けられない。
 * まだ無いものを作る権限は、プロジェクト単位にならざるを得ない。
 *
 * しかしこのプロジェクトは共有で、他の本番 Cloud Run も動いている。
 * プロジェクト単位の run.developer を配ると、
 * 受講者のCIが**他人の本番サービスも触れる**状態になる。それは通せない。
 *
 * そこで **入れ物は Terraform が作り、中身は Cloud Deploy が入れる** 形にする。
 * サービスが先に存在すれば、権限をサービス単位で付けられる。
 *
 * 講義でやった「インフラの形は Terraform、動かすものは CI/CD」の考え方が、
 * ここでは「権限を絞れる形はどれか」という理由からも要求される。
 */
resource "google_cloud_run_v2_service" "canary" {
  name     = "${var.user_name}-canary"
  location = "asia-northeast1"

  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = module.before.cloud_run_sa_email

    containers {
      // 最初は講師の共通イメージ。以降は Cloud Deploy が差し替える
      image = "asia-northeast1-docker.pkg.dev/${var.project_id}/${var.app_image_repo}/app"
      ports {
        container_port = 8080
      }
    }
  }

  /**
   * ★ 講義より広く無視している ★
   *
   * 講義の <自分の名前>-app は image だけを CI/CD に渡していた。
   * こちらは **サービス定義まるごと** を Cloud Deploy が持つので、
   * Terraform 側は「作る」だけにして中身は見ない。
   *
   * Cloud Deploy はリビジョンの追加・トラフィック割合・ラベルを触るため、
   * template / traffic / labels をまとめて無視する。
   *
   * ここまで広い ignore_changes は、
   * 「そのリソースの管理をほぼ手放す」という宣言。乱用しないこと。
   */
  lifecycle {
    ignore_changes = [
      template,
      traffic,
      labels,
      client,
      client_version,
    ]
  }
}

variable "app_image_repo" {
  description = "講師が用意した共通イメージのリポジトリ名"
  default     = "infra-study-common"
}

// 動作確認用に認証なしで見られるようにする
resource "google_cloud_run_v2_service_iam_member" "canary_public" {
  name     = google_cloud_run_v2_service.canary.name
  location = google_cloud_run_v2_service.canary.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

/**
 * Cloud Deploy がカナリア用サービスを更新する権限
 *
 * サービスが先に存在するので、**サービス単位**で付けられる。
 * 講義の Step3 と同じ形。
 */
resource "google_cloud_run_v2_service_iam_member" "deploy_developer" {
  name     = google_cloud_run_v2_service.canary.name
  location = google_cloud_run_v2_service.canary.location
  role     = "roles/run.developer"
  member   = "serviceAccount:${data.google_service_account.build.email}"
}

/**
 * 中間ファイル置き場
 *
 * Cloud Deploy は「リリース」を作るときに、
 * skaffold の出力(レンダリング済みのマニフェスト)をここに保存する。
 * どのリリースが何をデプロイしたかを後から追える。
 */
resource "google_storage_bucket" "deploy" {
  name                        = "${var.project_id}-deploy-${var.user_name}"
  location                    = "ASIA-NORTHEAST1"
  uniform_bucket_level_access = true
  force_destroy               = true
}

/**
 * 中間ファイル置き場への書き込み権限
 *
 * roles/clouddeploy.jobRunner にも storage.objects.* が入っているが、
 * それはプロジェクト全体に効く広い権限。
 * このバケットは自分で作ったものなので、バケット単位でも明示しておく。
 */
resource "google_storage_bucket_iam_member" "deploy_admin" {
  bucket = google_storage_bucket.deploy.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_service_account.build.email}"
}

/**
 * ターゲット = デプロイ先
 *
 * 本番・ステージングのように複数用意して、
 * パイプラインの中で順番に並べるのが本来の使い方。
 * 今回は勉強会なので1つだけ作る。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/clouddeploy_target
 */
/**
 * Cloud Deploy 実行SAが Cloud Run の実行SAになりすます権限
 *
 * 講義の Step3 と同じ理由。デプロイするサービスが名乗るSAを
 * 「使ってよい」という許可が要る。
 * 講義で既に <自分の名前>-build に付けてあるので、
 * ここで改めて足すものは無い(deploy.tf を参照)。
 */

resource "google_clouddeploy_target" "prod" {
  name     = "${var.user_name}-prod"
  location = "asia-northeast1"

  run {
    location = "projects/${var.project_id}/locations/asia-northeast1"
  }

  execution_configs {
    usages           = ["RENDER", "DEPLOY"]
    service_account  = data.google_service_account.build.email
    artifact_storage = "gs://${google_storage_bucket.deploy.name}"
  }

  deletion_policy = "DELETE"
}

/**
 * デリバリーパイプライン
 *
 * ステージを上から順に進む。今回は1ステージだけ。
 *
 * ★ カナリアの読み方 ★
 *   percentages = [10, 50]
 *
 *   10% → 50% → 100% と3段階で進む。
 *   最後の100%は自動で足されるので書かない。
 *
 *   各段階で止まり、人が `gcloud deploy rollouts advance` を叩くまで進まない。
 *   「様子を見る時間」がここで作れる。
 */
resource "google_clouddeploy_delivery_pipeline" "app" {
  name     = "${var.user_name}-pipeline"
  location = "asia-northeast1"

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.prod.name

      strategy {
        canary {
          runtime_config {
            cloud_run {
              // トラフィックの割り振りを Cloud Deploy に任せる
              automatic_traffic_control = true
            }
          }

          canary_deployment {
            percentages = [10, 50]
          }
        }
      }
    }
  }

  deletion_policy = "DELETE"
}

output "deploy_pipeline" {
  value = google_clouddeploy_delivery_pipeline.app.name
}

output "deploy_bucket" {
  value = google_storage_bucket.deploy.name
}

output "canary_url" {
  value = google_cloud_run_v2_service.canary.uri
}
