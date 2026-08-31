/**
 * Artifact Registry
 *
 * 第5回で一度作ったものと同じ。今回は CI/CD が push する先になる。
 *
 * ★ 第6回では作らなかった ★
 * 第6回の 0. before は、講師が用意した共通イメージを参照していた。
 * 「イメージが無いと Cloud Run は作れない」ので、
 * リポジトリ作成 → push → Cloud Run 作成 を1回の apply に畳めなかったため。
 *
 * 今日からは自分のリポジトリに、自分の push したコードから
 * ビルドされたイメージが入る。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository
 */
resource "google_artifact_registry_repository" "app" {
  location      = "asia-northeast1"
  repository_id = "${var.user_name}-repo"
  format        = "DOCKER"
  description   = "インフラ勉強会(GCP) 第7回"

  // 古いイメージを自動で消す
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}

/**
 * ビルド用のサービスアカウント(講師が作成済み)
 *
 * ★ AWSとの比較 ★
 *
 *   AWS  CodeBuild用 / CodeDeploy用 / CodePipeline用 の
 *        IAMロールが3つ必要だった
 *        (AWS版 第8回のコードでは、ロールとポリシーの定義だけで
 *         40行近くある)
 *
 *   GCP  ビルドもデプロイも Cloud Build がやるので、
 *        サービスアカウントは1つで済む
 *
 * ★ なぜ既定のサービスアカウントを使わないのか ★
 *
 * Cloud Build には昔から使われている既定のSAがあるが、
 * 2024年以降に作られたプロジェクトでは自動では作られず、
 * 明示的にSAを指定するのが推奨になっている。
 *
 * それ以上に大事なのは、**ビルドが持つ権限を自分で決められる**こと。
 * 既定SAは強い権限を持ちがちで、
 * 「CIが乗っ取られたら何ができるか」が読めなくなる。
 *
 * ★★ なぜ講師が作ってあるのか ★★
 *
 * このSAには `roles/logging.logWriter` が要る。
 * ログを書けないとビルドがそもそも始まらない。
 *
 * ところが Cloud Logging の権限は **プロジェクト単位でしか付けられない**。
 * そしてプロジェクト全体のIAMを書き換える権限
 * (`resourcemanager.projects.setIamPolicy`)は、
 * みんなで使っている共有プロジェクトでは配れない。
 * これを持つと、誰にでも好きなロールを付けられてしまうため。
 *
 * これは勉強会の都合ではなく、実務でもそうなる。
 *   プロジェクト全体のIAM → 基盤チームが持つ
 *   リソース単位のIAM     → 使う人が自分で付ける
 *
 * 今日の Step1・Step3 で自分が付けるのは、全部**リソース単位**の権限。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_account
 */
data "google_service_account" "build" {
  account_id = "${var.user_name}-build"
}

/**
 * Artifact Registry への push 権限
 *
 * ★ リポジトリ単位で付けている ★
 * プロジェクト全体に付ける必要はない。
 * 「このビルドは自分のリポジトリにだけ push できる」状態にする。
 *
 * これは自分で付けられる。付ける先がリソース(リポジトリ)だから。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam
 */
resource "google_artifact_registry_repository_iam_member" "build_writer" {
  location   = google_artifact_registry_repository.app.location
  repository = google_artifact_registry_repository.app.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_service_account.build.email}"
}

output "repository_url" {
  value = "${google_artifact_registry_repository.app.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "build_sa_email" {
  value = data.google_service_account.build.email
}
