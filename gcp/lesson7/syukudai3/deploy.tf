/**
 * Step2 でビルドが失敗した理由をつぶす
 *
 * ★ Cloud Build が Cloud Run にデプロイするには権限が2つ要る ★
 *
 *   1. デプロイ先を更新する権限          roles/run.developer
 *   2. 実行サービスアカウントになりすます権限  roles/iam.serviceAccountUser
 *
 * 1つ目だけでは通りません。ここが一番ハマるところ。
 *
 * ★ なぜ2つ要るのか ★
 *
 * Cloud Run のサービスには「動くときに名乗るサービスアカウント」が
 * 設定されている(第5回で作った <自分の名前>-run)。
 *
 * デプロイするということは、
 * 「そのサービスアカウントの権限で動くものを作る」ということ。
 * もし1つ目の権限だけでデプロイできてしまうと、
 * ビルドを乗っ取った人が、より強い権限のサービスアカウントを指定して
 * 好きなコードを動かせてしまう。
 *
 * だから「そのSAを使ってよい」という許可(actAs)が別に必要になる。
 *
 * AWSでいうと iam:PassRole と同じ考え方。
 * AWS版 第8回でも CodePipeline のロールに PassRole を入れていた。
 */

/**
 * 1. デプロイ先を更新する権限
 *
 * ★ プロジェクト全体ではなく、サービス単位で付けている ★
 *
 * roles/run.admin をプロジェクトに付ければ動くが、
 * それだと「このビルドは他人の Cloud Run も壊せる」状態になる。
 * 第1回でやった「必要な範囲に、必要なロールだけ」を実践する。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam
 */
resource "google_cloud_run_v2_service_iam_member" "build_developer" {
  name     = module.before.cloud_run_name
  location = module.before.cloud_run_location
  role     = "roles/run.developer"
  member   = "serviceAccount:${data.google_service_account.build.email}"
}

/**
 * 2. 実行サービスアカウントになりすます権限
 *
 * 第2回の IAP でも同じロールが出てきた。
 * 「このサービスアカウントを使ってよい」という許可。
 *
 * 付ける先は **プロジェクト** ではなく **サービスアカウント** であることに注意。
 * リソースとしてのサービスアカウントに、ポリシーを付けている。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account_iam
 */
resource "google_service_account_iam_member" "build_act_as_run" {
  service_account_id = module.before.cloud_run_sa_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_service_account.build.email}"
}
