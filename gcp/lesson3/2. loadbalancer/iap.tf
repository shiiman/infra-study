/**
 * IAP経由でVMに入るための権限(第2回と同じ3点セット)
 */
data "google_client_openid_userinfo" "me" {}

resource "google_iap_tunnel_instance_iam_member" "web" {
  zone     = google_compute_instance.web.zone
  instance = google_compute_instance.web.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = "user:${data.google_client_openid_userinfo.me.email}"
}

resource "google_compute_instance_iam_member" "web_os_login" {
  zone          = google_compute_instance.web.zone
  instance_name = google_compute_instance.web.name
  role          = "roles/compute.osAdminLogin"
  member        = "user:${data.google_client_openid_userinfo.me.email}"
}

resource "google_service_account_iam_member" "web_sa_user" {
  service_account_id = google_service_account.web.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${data.google_client_openid_userinfo.me.email}"
}
