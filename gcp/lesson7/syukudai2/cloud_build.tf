/**
 * 講師が用意した GitHub 接続の情報
 *
 * ★ GitHub連携は Terraform だけでは完結しません ★
 *
 * Cloud Build が GitHub のリポジトリを見るには、次の2つが要ります。
 *
 *   1. GitHub 側に「Cloud Build」の GitHub App をインストールする
 *      → ブラウザでの作業。app_installation_id が発行される
 *   2. GitHub のアクセストークンを Secret Manager に入れる
 *      → 接続(connection)がこれを使って GitHub を読む
 *
 * どちらも人が手でやる必要があり、コードにはできません。
 * 勉強会では**講師が1回だけ**やってあり、
 * 受講者はその接続にぶら下がるだけで済むようにしてあります。
 *
 * ★ AWSとの比較 ★
 *   CodeCommit は AWS の中にリポジトリがあったので、この手順が無かった。
 *   GCPの Cloud Source Repositories も同じ立ち位置でしたが、
 *   **2024年6月に新規提供を終了**しているので、今から使うものではありません。
 *   GCP で CI/CD を組むなら GitHub 連携が前提になります。
 */
variable "cloudbuild_repository" {
  description = "講師が作成した Cloud Build のリポジトリリンク(フルリソース名)"
  type        = string
}

/**
 * ビルドトリガー
 *
 * ★ AWSとの比較 ★
 *
 *   AWS  CodePipeline を作り、その中に
 *        Source(CodeCommit) / Build(CodeBuild) / Deploy(CodeDeploy)
 *        の3ステージを定義した。3サービス + パイプラインで4つ
 *
 *   GCP  トリガー1つ。ビルドの中身は cloudbuild.yaml に書く
 *
 * ★ 全員で1つのリポジトリを共有する ★
 *
 * リポジトリは全員共通で、**ブランチで自分の担当を分ける**。
 *   - 自分の名前のブランチに push すると、自分のトリガーだけが動く
 *   - 他の人のブランチに push しても、自分のビルドは走らない
 *
 * cloudbuild.yaml も全員で共有するので、
 * 「どのリポジトリに push するか」「どのサービスにデプロイするか」は
 * substitutions でトリガーから渡す。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_trigger
 */
resource "google_cloudbuild_trigger" "app" {
  name     = "${var.user_name}-deploy"
  location = "asia-northeast1"

  // Step1で確認した、自分専用のサービスアカウントでビルドする
  service_account = data.google_service_account.build.name

  repository_event_config {
    repository = var.cloudbuild_repository

    push {
      // ★ 自分の名前のブランチだけを見る
      //   ^ と $ で囲まないと、部分一致で他の人のブランチにも反応する
      branch = "^${var.user_name}$"
    }
  }

  // リポジトリのルートにある cloudbuild.yaml を読む
  filename = "cloudbuild.yaml"

  /**
   * 置換変数
   *
   * cloudbuild.yaml 側では ${_REPO} のように書いて受け取る。
   * ユーザ定義の変数は必ずアンダースコアで始める決まり。
   *
   * $PROJECT_ID / $SHORT_SHA / $BRANCH_NAME などは
   * Cloud Build が自動で入れてくれる(組み込み変数)。
   */
  substitutions = {
    _REGION  = "asia-northeast1"
    _REPO    = google_artifact_registry_repository.app.repository_id
    _SERVICE = module.before.cloud_run_name
  }
}

output "trigger_name" {
  value = google_cloudbuild_trigger.app.name
}
