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
 * カスタムロールが反映されるまで待つ
 *
 * 作った直後のカスタムロールは、バケット側のIAMからまだ見えない。
 * そのまま付与すると、ロールは実在するのに次のエラーになる。
 *
 *   Error 400: Role (projects/.../roles/...) does not exist in the resource's hierarchy
 *
 * 結果整合性(あとから全体に行き渡る仕組み)によるもので、待つしかない。
 * 実測では作成から 12〜18秒で見えるようになり、まれに20秒を超える。
 * 余裕を見て30秒待つ。待つのは作成時だけで、2回目以降の apply では待たない。
 *
 * https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep
 */
resource "time_sleep" "wait_for_custom_role" {
  depends_on      = [google_project_iam_custom_role.object_reader]
  create_duration = "30s"
}

/**
 * 作成したカスタムロールを、バケット単位でサービスアカウントに付与する
 *
 * カスタムロールはプロジェクトに属するが、付与先はバケットなどの
 * 個別リソースを指定できる。
 */
resource "google_storage_bucket_iam_member" "app_custom_role" {
  bucket = data.google_storage_bucket.tfstate.name
  role   = google_project_iam_custom_role.object_reader.name
  member = "serviceAccount:${google_service_account.app.email}"

  // ロールを参照しているだけでは「作った直後」に付与してしまう。
  // 待ちを挟むために time_sleep への依存を明示する
  depends_on = [time_sleep.wait_for_custom_role]
}
