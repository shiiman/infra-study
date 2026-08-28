/**
 * サービスアカウント作成
 * 「人」ではなく「プログラム」に紐づくGCP独自のプリンシパル
 * AWSのIAMロールに近いが、それ自体がIDとして扱える点が異なる
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
 */
resource "google_service_account" "app" {
  // account_idは 6〜30文字 / 小文字英数字とハイフンのみ
  account_id   = "${var.user_name}-app"
  display_name = "${var.user_name} app service account"
  description  = "インフラ勉強会(GCP) 第1回で作成するアプリ用サービスアカウント"
}
