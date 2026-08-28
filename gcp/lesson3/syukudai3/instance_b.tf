/**
 * 宿題2: webインスタンスを別ゾーンにも置いて冗長化する
 *
 * ★ AWS版との違い ★
 * AWS版では「カスタムAMIを作って別AZにEC2を立てる」という手順だった。
 * GCPも同じことができるが、ここではもう一段シンプルにして
 * 同じイメージから2台目を立て、起動スクリプトでアプリを立ち上げる。
 *
 * ★ インスタンスグループはゾーン単位 ★
 * 1つのインスタンスグループに別ゾーンのVMは入れられない。
 * ゾーンごとにインスタンスグループを作り、
 * バックエンドサービスに backend ブロックを2つぶら下げる。
 */

/**
 * 2台目のwebインスタンス(asia-northeast1-b)
 *
 * 起動スクリプトでDockerとアプリを自動セットアップする。
 * 宿題1でやった「手で入れて docker run」を自動化したもの。
 */
resource "google_compute_instance" "web_b" {
  name = "${var.user_name}-web-b"

  machine_type = "e2-medium"

  zone = "asia-northeast1-b"

  tags = ["${var.user_name}-web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = module.before.private_subnet_id
  }

  metadata = {
    enable-oslogin = "TRUE"

    startup-script = <<-SCRIPT
      #!/bin/bash
      set -e
      if ! command -v docker >/dev/null 2>&1; then
        apt-get update
        apt-get install -y docker.io git
        systemctl enable --now docker
      fi
      if [ ! -d /opt/infra-study ]; then
        git clone https://github.com/shiiman/infra-study.git /opt/infra-study
      fi
      cd "/opt/infra-study/gcp/lesson3/1. web_instance/web_app"
      docker build -t app:0.1 .
      docker rm -f app 2>/dev/null || true
      docker run -d --name app -p 80:8080 --restart always app:0.1
    SCRIPT
  }

  service_account {
    email  = google_service_account.web.email
    scopes = ["cloud-platform"]
  }
}

/**
 * 2台目用のインスタンスグループ(asia-northeast1-b)
 */
resource "google_compute_instance_group" "web_b" {
  name = "${var.user_name}-web-b-ig"
  zone = "asia-northeast1-b"

  instances = [google_compute_instance.web_b.id]

  named_port {
    name = "http"
    port = 80
  }
}

/**
 * 2台目にもIAPで入れるようにする
 */
resource "google_iap_tunnel_instance_iam_member" "web_b" {
  zone     = google_compute_instance.web_b.zone
  instance = google_compute_instance.web_b.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = "user:${data.google_client_openid_userinfo.me.email}"
}

resource "google_compute_instance_iam_member" "web_b_os_login" {
  zone          = google_compute_instance.web_b.zone
  instance_name = google_compute_instance.web_b.name
  role          = "roles/compute.osAdminLogin"
  member        = "user:${data.google_client_openid_userinfo.me.email}"
}
