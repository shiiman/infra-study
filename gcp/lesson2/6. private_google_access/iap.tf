/**
 * データブロック: 今Terraformを実行している自分の情報を取得
 */
data "google_client_openid_userinfo" "me" {}

/**
 * IAP経由でVMに入るために必要な権限
 *
 * Firewall Rule(ネットワーク層の許可)だけでは入れない。
 * GCPでは以下の3つのゲートを全て通る必要がある。
 *
 *   1. Firewall Rule                     : 35.235.240.0/20 からのtcp:22 (firewall.tf)
 *   2. roles/iap.tunnelResourceAccessor  : IAPトンネルを張る権限
 *   3. roles/compute.osAdminLogin        : OSにログインする権限(sudo付き)
 *      + roles/iam.serviceAccountUser    : VMのサービスアカウントを使う権限
 *
 * いずれもプロジェクト全体ではなく、インスタンス/サービスアカウント単位で付与している。
 */

/**
 * 1. IAPトンネルを張る権限(インスタンス単位)
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_tunnel_instance_iam
 */
resource "google_iap_tunnel_instance_iam_member" "web" {
  zone     = google_compute_instance.web.zone
  instance = google_compute_instance.web.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = "user:${data.google_client_openid_userinfo.me.email}"
}

resource "google_iap_tunnel_instance_iam_member" "db" {
  zone     = google_compute_instance.db.zone
  instance = google_compute_instance.db.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = "user:${data.google_client_openid_userinfo.me.email}"
}

/**
 * 2. OSにログインする権限(インスタンス単位)
 * osLogin      : 一般ユーザとしてログイン
 * osAdminLogin : sudo が使えるユーザとしてログイン
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_iam
 */
resource "google_compute_instance_iam_member" "web_os_login" {
  zone          = google_compute_instance.web.zone
  instance_name = google_compute_instance.web.name
  role          = "roles/compute.osAdminLogin"
  member        = "user:${data.google_client_openid_userinfo.me.email}"
}

resource "google_compute_instance_iam_member" "db_os_login" {
  zone          = google_compute_instance.db.zone
  instance_name = google_compute_instance.db.name
  role          = "roles/compute.osAdminLogin"
  member        = "user:${data.google_client_openid_userinfo.me.email}"
}

/**
 * 3. VMに紐づくサービスアカウントを使う権限(サービスアカウント単位)
 * サービスアカウント付きのVMへログインする際に必要
 */
resource "google_service_account_iam_member" "web_sa_user" {
  service_account_id = google_service_account.web.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${data.google_client_openid_userinfo.me.email}"
}

resource "google_service_account_iam_member" "db_sa_user" {
  service_account_id = google_service_account.db.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${data.google_client_openid_userinfo.me.email}"
}
