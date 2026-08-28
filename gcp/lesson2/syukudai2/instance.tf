/**
 * インスタンス用サービスアカウント作成
 *
 * GCPではFirewall Ruleの許可元/許可先をサービスアカウントで指定できる。
 * AWSで「webのSGからdbのSGへ」と書いていた部分の代替になるので、
 * VMごとに専用のサービスアカウントを用意しておく。
 */
resource "google_service_account" "web" {
  account_id   = "${var.user_name}-web"
  display_name = "${var.user_name} web instance"
}

resource "google_service_account" "db" {
  account_id   = "${var.user_name}-db"
  display_name = "${var.user_name} db instance"
}

/**
 * インスタンス作成
 * コンピューティングの詳細は第3回で説明する
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
 */
resource "google_compute_instance" "web" {
  name         = "${var.user_name}-web"
  machine_type = "e2-micro"
  zone         = "asia-northeast1-a"

  // ネットワークタグ: Firewall Ruleの適用先を指定するためのラベル
  tags = ["${var.user_name}-web"]

  boot_disk {
    initialize_params {
      // イメージファミリーを指定すると、その時点の最新版が使われる
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id

    // access_configブロックを書くと外部IPが付与される
    access_config {}
  }

  metadata = {
    // OS Loginを有効化する(SSH鍵の配布が不要になる)
    enable-oslogin = "TRUE"
  }

  service_account {
    email = google_service_account.web.email

    // scopesはレガシーな仕組み。cloud-platformにしておき、
    // 実際の権限はIAMロールで絞るのが現在の推奨
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "db" {
  name         = "${var.user_name}-db"
  machine_type = "e2-micro"
  zone         = "asia-northeast1-a"

  tags = ["${var.user_name}-db"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id

    // access_configブロックを書かない = 外部IPなし
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = google_service_account.db.email
    scopes = ["cloud-platform"]
  }
}
