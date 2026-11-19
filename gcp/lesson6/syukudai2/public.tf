/**
 * バケットを公開する
 *
 * ★ 「Access Denied → 公開設定」の場面 ★
 *
 * AWSでは CloudFront の OAI(オリジンアクセスアイデンティティ)を作り、
 * その principal に GetObject を許可するバケットポリシーを書く。
 *
 * GCP の Cloud CDN は、既定では「公開されたオブジェクト」を読みに行く。
 * そのため、allUsers に閲覧権限を与える必要がある。
 *
 * ★ 第1回 S25 で「allUsers は事故の元」と言ったやつ ★
 * ここでは意図的に公開するので正しい使い方。
 * ただし「バケット全体が誰でも直接読める」状態になる点は理解しておくこと。
 *   → CDN経由でなくても https://storage.googleapis.com/<バケット>/<オブジェクト>
 *     で読めてしまう
 *
 * ★ 非公開のまま配信したい場合 ★
 *   署名付きURL / 署名付きCookie を使う
 *   Cloud CDN の署名付きリクエスト機能を使う
 *   → 講義の「非公開のまま配信したい場合」で説明します
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam
 */
resource "google_storage_bucket_iam_member" "public" {
  bucket = google_storage_bucket.static.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
