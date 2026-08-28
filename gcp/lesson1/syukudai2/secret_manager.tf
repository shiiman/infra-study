/**
 * Secret Manager のシークレット作成
 *
 * 「入れ物」だけをTerraformで作る。中身(値)はTerraformで管理しない。
 * secret_data をTerraformに書くと、tfstateに平文で保存されてしまうため。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret
 */
resource "google_secret_manager_secret" "app" {
  secret_id = "${var.user_name}-app-secret"

  replication {
    user_managed {
      replicas {
        location = "asia-northeast1"
      }
    }
  }
}

/**
 * シークレット単位のIAM
 *
 * プロジェクト全体に roles/secretmanager.secretAccessor を付けると
 * プロジェクト内の全シークレットが読めてしまう。
 * このシークレットだけを読ませたいので、リソース単位で付与する。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam
 */
resource "google_secret_manager_secret_iam_member" "app_accessor" {
  secret_id = google_secret_manager_secret.app.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}
