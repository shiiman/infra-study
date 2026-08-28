/**
 * カスタムロール作成
 *
 * 事前定義ロールでは粒度が粗すぎる場合に、権限(permission)を選んで自分で組み立てる。
 * roles/storage.objectViewer には storage.objects.get / storage.objects.list に加えて
 * いくつかの権限が含まれているが、ここでは「読むのに必要な2つ」だけに絞っている。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam_custom_role
 */
resource "google_project_iam_custom_role" "object_reader" {
  // role_idに使えるのは英数字・アンダースコア・ピリオドのみ(ハイフンは使えない)
  role_id     = "${replace(var.user_name, "-", "_")}_object_reader"
  title       = "${var.user_name} object reader"
  description = "オブジェクトの読み取りだけを許可するカスタムロール"

  permissions = [
    "storage.objects.get",
    "storage.objects.list",
  ]
}

/**
 * 作成したカスタムロールを、バケット単位でサービスアカウントに付与する
 *
 * カスタムロールはプロジェクトに属するが、付与先はバケットなどの
 * 個別リソースを指定できる。
 */
resource "google_storage_bucket_iam_member" "app_custom_role" {
  bucket = google_storage_bucket.tfstate.name
  role   = google_project_iam_custom_role.object_reader.name
  member = "serviceAccount:${google_service_account.app.email}"
}
