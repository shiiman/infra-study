/**
 * 問2 模範解答: VM を2台
 *
 * 出題範囲: 第3回
 *
 * ★ 採点のポイント ★
 *   1. 2台とも private サブネットにあるか
 *   2. 外部IPを持っていないか(access_config を書いていないか)
 *      → 書いてあると外部IPが付いてしまう。減点
 *   3. startup-script が指定どおり入っているか
 *   4. ネットワークタグが付いているか(問4のFirewallで使う)
 *   5. count か for_each で2台作れているか
 *      → 同じブロックをコピペで2つ書いても動くが、減点対象にはしない
 */

/**
 * VM が名乗るサービスアカウント
 *
 * 既定のサービスアカウントを使うと権限が広すぎるので、
 * 専用のものを作る(第3回でやったこと)。
 */
resource "google_service_account" "web" {
  account_id   = "${var.user_name}-web"
  display_name = "${var.user_name} web instance"
}

resource "google_compute_instance" "web" {
  count = 2

  name         = "${var.user_name}-web${count.index + 1}"
  machine_type = "e2-medium"
  zone         = "asia-northeast1-a"

  // 問4の Firewall ルールで使う
  tags = ["${var.user_name}-web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
    // ★ access_config を書かない = 外部IPを持たない
  }

  service_account {
    email  = google_service_account.web.email
    scopes = ["cloud-platform"]
  }

  /**
   * 問題文で指定された startup-script
   *
   * 80番ポートで "Congratulation!!" を返すだけのもの。
   * apt-get するので、問1の Cloud NAT が無いと失敗する。
   */
  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "Congratulation!!" > /var/www/html/index.html
    systemctl restart nginx
  EOT
}

output "instance_names" {
  value = google_compute_instance.web[*].name
}
