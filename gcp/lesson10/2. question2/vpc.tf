/**
 * 問1 模範解答: ネットワーク
 *
 * 出題範囲: 第2回
 *
 * ★ 採点のポイント ★
 *   1. VPC が auto_create_subnetworks = false になっているか
 *      → true だと全リージョンにサブネットが勝手にできてしまう
 *   2. サブネットが2つ(public / private)あるか
 *   3. private サブネットから外に出る経路(Cloud Router + Cloud NAT)があるか
 *      → これが無いと問2の startup-script が動かない
 *   4. IAP からの SSH を許可する Firewall ルールがあるか
 *      → 動作確認のためにVMへ入りたくなったときに必要
 */
variable "subnet_public_cidr" {}
variable "subnet_private_cidr" {}

resource "google_compute_network" "vpc" {
  name = "${var.user_name}-vpc"

  // ★ false にしないと全リージョンにサブネットができる
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name          = "${var.user_name}-public-subnet"
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_public_cidr
  region        = "asia-northeast1"
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.user_name}-private-subnet"
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_private_cidr
  region        = "asia-northeast1"

  // 外部IPを持たないVMからGoogle APIへ到達させる
  private_ip_google_access = true
}

/**
 * Cloud Router + Cloud NAT
 *
 * private サブネットのVMは外部IPを持たないので、
 * このままではインターネットに出られない。
 * 問2の startup-script が apt-get するために必要。
 */
resource "google_compute_router" "router" {
  name    = "${var.user_name}-router"
  network = google_compute_network.vpc.id
  region  = "asia-northeast1"
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.user_name}-nat"
  router = google_compute_router.router.name
  region = "asia-northeast1"

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

/**
 * IAP からの SSH を許可する
 *
 * 35.235.240.0/20 は IAP の固定レンジ。
 * 動作確認でVMに入りたいときに必要。
 */
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.user_name}-allow-iap-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.user_name}-web"]
}

output "vpc_name" { value = google_compute_network.vpc.name }
output "private_subnet_name" { value = google_compute_subnetwork.private.name }
