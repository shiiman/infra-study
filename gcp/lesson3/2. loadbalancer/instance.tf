/**
 * webインスタンス用サービスアカウント
 */
resource "google_service_account" "web" {
  account_id   = "${var.user_name}-web"
  display_name = "${var.user_name} web instance"
}

/**
 * webインスタンス作成
 *
 * 外部IPを持たせない。インターネットへの出口は第2回で作ったCloud NAT。
 * 外部からのアクセスは、このあと作るロードバランサ経由にする。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
 */
resource "google_compute_instance" "web" {
  name = "${var.user_name}-web"

  // e2-micro(共有CPU)ではアプリのビルドが遅い。
  // 第2回のVMは疎通確認だけだったので e2-micro でよかったが、
  // 第3回からはコンテナをビルドするので e2-medium にする。
  machine_type = "e2-medium"

  zone = "asia-northeast1-a"

  tags = ["${var.user_name}-web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"

      // Persistent Disk のサイズと種類
      // pd-balanced はSSDとHDDの中間。省略時のデフォルト
      size = 10
      type = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = module.before.private_subnet_id
    // access_configを書かない = 外部IPなし
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = google_service_account.web.email
    scopes = ["cloud-platform"]
  }
}
