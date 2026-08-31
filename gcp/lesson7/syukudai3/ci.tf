/**
 * 宿題3: ブランチによってやることを変える
 *
 * 講義では「自分の名前のブランチに push したらビルドしてデプロイ」
 * の1本だけだった。
 *
 * 実務では、作業中のブランチでいきなり本番にデプロイされては困る。
 * 「ビルドが通るかだけ見たい」段階と
 * 「出してよい」段階を分ける。
 *
 *   <自分の名前>-dev  ビルドと push だけ(デプロイしない)
 *   <自分の名前>      ビルドして Cloud Run にデプロイする(講義で作ったトリガー)
 *
 * ★ ポイント: 分けるのはトリガーとビルド構成ファイル ★
 *
 * 1つの cloudbuild.yaml に if を書くのではなく、
 * **やることが違うならファイルを分ける**。
 * Cloud Build のステップに条件分岐は無い(書けなくはないが読みにくくなる)。
 *
 * ★ AWSとの対応 ★
 * CodePipeline はパイプライン1本にソースが1つ紐づく作りなので、
 * ブランチごとにパイプラインを丸ごと複製する必要があった。
 * Cloud Build はトリガーが軽いので、増やすのが安い。
 */
resource "google_cloudbuild_trigger" "ci" {
  name     = "${var.user_name}-ci"
  location = "asia-northeast1"

  service_account = data.google_service_account.build.name

  repository_event_config {
    repository = var.cloudbuild_repository

    push {
      // <自分の名前>-dev ブランチ
      branch = "^${var.user_name}-dev$"
    }
  }

  // デプロイのステップが入っていない別のファイルを読む
  filename = "cloudbuild-ci.yaml"

  substitutions = {
    _REGION = "asia-northeast1"
    _REPO   = google_artifact_registry_repository.app.repository_id
  }
}

output "ci_trigger_name" {
  value = google_cloudbuild_trigger.ci.name
}
