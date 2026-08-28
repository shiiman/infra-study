/**
 * データブロック
 * 今Terraformを実行しているプリンシパル(自分)の情報をGCPから取得する
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_openid_userinfo
 */
data "google_client_openid_userinfo" "me" {}

/**
 * サービスアカウントに対するIAM(権限借用の許可)
 *
 * 「自分」が「このサービスアカウント」になりすます(impersonate)ことを許可する。
 * ロールの付与先がプロジェクトではなくサービスアカウントそのものである点に注目。
 * これによりサービスアカウントキー(JSONファイル)を作らずに済む。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account_iam
 */
resource "google_service_account_iam_member" "token_creator" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${data.google_client_openid_userinfo.me.email}"
}

/**
 * バケットに対するIAM
 *
 * サービスアカウントに、このバケットの中身を読む権限だけを与える。
 * プロジェクト全体ではなくバケット単位で付与するのが最小権限の基本。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam
 */
resource "google_storage_bucket_iam_member" "app_object_viewer" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.app.email}"
}
